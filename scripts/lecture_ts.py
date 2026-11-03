# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Lire une table littérale d'un fichier TypeScript de coprofirst, sans l'exécuter.

`export const PAGES: PageDef[] = [ { id: '…', onglets: [ … ] }, … ];` devient une
liste de dictionnaires Python. Ce qui se lit : chaînes ('…', "…", `…` sans
interpolation), nombres, `true` / `false` / `null`, objets et tableaux imbriqués,
et un identifiant nu (une constante comme `TITRE_ARCHIVES`), rendu en
`Identifiant`. Un étalement (`...AUTRE_TABLE`) est omis : l'appelant lit l'autre
table par son nom. Toute autre valeur (appel, fonction fléchée, gabarit interpolé) est
sautée jusqu'à la virgule de son niveau et vaut `None` : la table se lit quand
même, et l'appelant qui a besoin de la valeur le voit.

Les commentaires se sautent, y compris au milieu d'un objet — c'est ce qui faisait
manquer des onglets à une lecture par expressions régulières.
"""

from __future__ import annotations

import re

JETON = re.compile(
    r"""\s+|//[^\n]*|/\*.*?\*/"""  # blancs et commentaires, ignorés
    r"""|(?P<chaine>'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|`(?:\\.|[^`\\])*`)"""
    r"""|(?P<nombre>-?\d+(?:\.\d+)?)"""
    r"""|(?P<mot>[A-Za-z_$][\w$]*)"""
    r"""|(?P<signe>\.\.\.|=>|[{}\[\](),:?.=<>!&|+\-*/%;])""",
    re.S,
)
ECHAPPEMENT = re.compile(r"\\u\{([0-9a-fA-F]+)\}|\\u([0-9a-fA-F]{4})|\\(.)", re.S)


class Identifiant(str):
    """Un nom de constante écrit à la place d'une valeur littérale."""


def _chaine(brute: str) -> str:
    def un(m: re.Match) -> str:
        code = m.group(1) or m.group(2)
        if code:
            return chr(int(code, 16))
        return {"n": "\n", "t": "\t"}.get(m.group(3), m.group(3))
    return ECHAPPEMENT.sub(un, brute[1:-1])


def _jetons(texte: str) -> list[tuple[str, str]]:
    """Les jetons de la valeur qui ouvre le texte, jusqu'à sa fermeture — pas au-delà :
    la suite du fichier peut contenir ce que ce lecteur ne connaît pas (regex, JSX)."""
    sortie, i, profondeur = [], 0, 0
    while i < len(texte):
        m = JETON.match(texte, i)
        if not m:
            raise ValueError(f"lecture_ts : caractère inattendu {texte[i]!r} (position {i})")
        i = m.end()
        if m.lastgroup:
            sortie.append((m.lastgroup, m.group(m.lastgroup)))
            val = m.group(m.lastgroup)
            profondeur += (val in "{[(") - (val in "}])") if m.lastgroup == "signe" else 0
            if profondeur == 0:
                break
    return sortie


class _Lecteur:
    def __init__(self, jetons: list[tuple[str, str]]) -> None:
        self.j, self.i = jetons, 0

    def vu(self) -> tuple[str, str]:
        return self.j[self.i] if self.i < len(self.j) else ("fin", "")

    def prendre(self, attendu: str | None = None) -> tuple[str, str]:
        jeton = self.vu()
        if attendu is not None and jeton[1] != attendu:
            raise ValueError(f"lecture_ts : « {attendu} » attendu, « {jeton[1]} » lu")
        self.i += 1
        return jeton

    def sauter(self) -> None:
        """Saute une valeur illisible : jusqu'à la virgule ou la fermeture de son niveau."""
        profondeur = 0
        while True:
            genre, val = self.vu()
            if genre == "fin":
                return
            if profondeur == 0 and val in (",", "}", "]"):
                return
            if val in ("{", "[", "("):
                profondeur += 1
            elif val in ("}", "]", ")"):
                profondeur -= 1
            self.i += 1

    def valeur(self):
        debut = self.i
        genre, val = self.vu()
        if val == "{":
            v = self.objet()
        elif val == "[":
            v = self.tableau()
        elif genre == "chaine" and not (val.startswith("`") and "${" in val):
            self.prendre()
            v = _chaine(val)
        elif genre == "nombre":
            self.prendre()
            v = float(val) if "." in val else int(val)
        elif genre == "mot":
            self.prendre()
            v = {"true": True, "false": False, "null": None}.get(val, Identifiant(val))
        else:
            v = None
        if self.vu()[1] not in (",", "}", "]"):  # suite d'expression : illisible
            self.i = debut
            self.sauter()
            return None
        return v

    def objet(self) -> dict:
        self.prendre("{")
        sortie = {}
        while self.vu()[1] != "}":
            if self.vu()[1] == "...":
                self.sauter()
            else:
                genre, cle = self.prendre()
                cle = _chaine(cle) if genre == "chaine" else cle
                if self.vu()[1] == "?":
                    self.prendre()
                if self.vu()[1] == ":":
                    self.prendre(":")
                    sortie[cle] = self.valeur()
                else:  # propriété abrégée `{ id }` ou méthode : sans valeur littérale
                    self.sauter()
                    sortie[cle] = None
            if self.vu()[1] == ",":
                self.prendre()
        self.prendre("}")
        return sortie

    def tableau(self) -> list:
        self.prendre("[")
        sortie = []
        while self.vu()[1] != "]":
            if self.vu()[1] == "...":  # `...AUTRE_TABLE` : se lit à part, par son nom
                self.sauter()
            else:
                sortie.append(self.valeur())
            if self.vu()[1] == ",":
                self.prendre()
        self.prendre("]")
        return sortie


def table(texte: str, nom: str) -> list:
    """La table littérale `export const <nom>… = [ … ]` du texte, lue en Python."""
    m = re.search(rf"\bconst {re.escape(nom)}\b[^=]*=\s*\[", texte)
    if not m:
        raise ValueError(f"lecture_ts : table {nom} introuvable")
    lecteur = _Lecteur(_jetons(texte[m.end() - 1 :]))
    return lecteur.tableau()
