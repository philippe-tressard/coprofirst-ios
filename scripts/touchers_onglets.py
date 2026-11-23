# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Un onglet se touche JUSQU'À SON EFFET, `toucher(_:jusqua:)` (#183, #334).

Nu, un toucher d'onglet perdu sous charge laisse la page d'avant, sans reprise : le test
rougit 30 s plus loin, sur l'assertion suivante (PR #332, job 137398553134). Ce juge lit
l'appel ENTIER — swift-format le coupe parfois sur plusieurs lignes — et refuse un
`toucher(…)` sans `jusqua:` dont le premier argument désigne un onglet :

- un identifiant d'accessibilité dont un segment est `onglet` ou `onglets`, quel que soit
  son préfixe et l'outil qui le cherche (`elementAcces("onglet.badges")`,
  `el(app, "residence.sommaire.onglet.carnet")`, `"communaute.onglet.annonces"`) ;
- une variable dont le nom commence par `onglet` (`onglet`, `onglets`, `ongletCarnet`) :
  c'est la convention qui rend lisible un onglet trouvé par son LIBELLÉ.

Hors de sa vue, et dit : un onglet trouvé par son libellé en ligne
(`app.buttons["Carnet d’entretien"]`) ou rangé dans une variable nommée autrement. Un
texte ne dit pas qu'un libellé est un onglet ; la convention de nom le dit.

Exceptions DÉCLARÉES (`EXCEPTIONS`) : un toucher qui n'est pas idempotent — ouvrir un menu,
qu'une reprise refermerait — reste nu, avec sa raison ; une exception qui ne sert plus
est refusée.

Sortie : 0 conforme, 1 refus (chaque appel fautif à sa ligne). `--autotest` prouve que le
juge refuse et laisse passer.
"""

from __future__ import annotations

import contextlib
import io
import pathlib
import re
import sys
import tempfile

# (fichier relatif à la racine, appel normalisé) → la raison, datée.
EXCEPTIONS = {
    ("CoproFirstUITests/AvisReglementUITests.swift", "app.toucher(onglets)"): (
        "aux tailles d'accessibilité, les onglets de la Résidence sont un MENU : une reprise "
        "le refermerait (toucher non idempotent, Attente.swift) — 23/11/2026, #334"
    ),
}

APPEL = re.compile(r"(?<![\w])toucher\s*\(")
SEGMENT_ONGLET = re.compile(r"(?:^|\.)onglets?(?:\.|$)")
VARIABLE_ONGLET = re.compile(r"^onglet\w*$")
LITTERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')


def sans_commentaires(texte: str) -> str:
    """Le texte, commentaires `//` remplacés par des espaces (lignes et positions gardées)."""
    sortie = []
    for ligne in texte.split("\n"):
        dans_chaine, i = False, 0
        while i < len(ligne):
            c = ligne[i]
            if dans_chaine and c == "\\":
                i += 2
                continue
            if c == '"':
                dans_chaine = not dans_chaine
            elif not dans_chaine and ligne.startswith("//", i):
                ligne = ligne[:i] + " " * (len(ligne) - i)
                break
            i += 1
        sortie.append(ligne)
    return "\n".join(sortie)


def arguments(texte: str, debut: int) -> list[str] | None:
    """Les arguments de l'appel dont la parenthèse ouvrante est à `debut`, coupés aux
    virgules de premier niveau ; None si l'appel ne se ferme pas."""
    profondeur, dans_chaine, i, courant, parts = 0, False, debut, [], []
    while i < len(texte):
        c = texte[i]
        if dans_chaine:
            courant.append(c)
            if c == "\\" and i + 1 < len(texte):
                courant.append(texte[i + 1])
                i += 1
            elif c == '"':
                dans_chaine = False
        elif c == '"':
            dans_chaine = True
            courant.append(c)
        elif c in "([":
            profondeur += 1
            if profondeur > 1:
                courant.append(c)
        elif c in ")]":
            profondeur -= 1
            if profondeur == 0:
                parts.append("".join(courant))
                return [" ".join(p.split()) for p in parts]
            courant.append(c)
        elif c == "," and profondeur == 1:
            parts.append("".join(courant))
            courant = []
        else:
            courant.append(c)
        i += 1
    return None


def designe_un_onglet(argument: str) -> bool:
    if VARIABLE_ONGLET.match(argument):
        return True
    return any(SEGMENT_ONGLET.search(m.group(1)) for m in LITTERAL.finditer(argument))


def nus(chemin: str, texte: str) -> list[tuple[int, str]]:
    """Les touchers d'onglet sans `jusqua:` : (ligne, appel normalisé)."""
    propre = sans_commentaires(texte)
    trouves = []
    for m in APPEL.finditer(propre):
        if propre[max(0, m.start() - 5) : m.start()] == "func ":
            continue
        args = arguments(propre, m.end() - 1)
        if not args or any(a.startswith("jusqua:") for a in args[1:]):
            continue
        if designe_un_onglet(args[0]):
            appel = " ".join(propre[m.start() : propre.index("(", m.start())].split())
            prefixe = propre[: m.start()]
            objet = re.search(r"([\w.]*\.)$", prefixe)
            nom = (objet.group(1) if objet else "") + appel
            trouves.append((propre.count("\n", 0, m.start()) + 1, f"{nom}({', '.join(args)})"))
    return trouves


def juger(racine: pathlib.Path, fichiers: list[str]) -> int:
    fautes, servies = 0, set()
    for f in fichiers:
        for ligne, appel in nus(f, (racine / f).read_text(encoding="utf-8")):
            if (f, appel) in EXCEPTIONS:
                servies.add((f, appel))
                continue
            print(f"❌ {f}:{ligne} : {appel} — app.toucher(onglet, jusqua: effet) (#183, #334)")
            fautes += 1
    for f, appel in sorted(set(EXCEPTIONS) - servies):
        if f in fichiers:
            print(f"❌ exception de {f} sans emploi : « {appel} » — la retirer de EXCEPTIONS")
            fautes += 1
    return 1 if fautes else 0


def autotest() -> int:
    refuses = {
        "identifiant": 'app.toucher(app.elementAcces("onglet.badges"))',
        "préfixe": 'app.toucher(app.elementAcces("residence.sommaire.onglet.carnet"))',
        "autre outil": 'app.toucher(el(app, "communaute.onglet.annonces"))',
        "variable": "app.toucher(onglet)",
        "variable au pluriel": "app.toucher(onglets)",
        "plusieurs lignes": 'app.toucher(\n    app.elementAcces("site.onglet.\\(id)"))',
        "essais sans effet": "app.toucher(ongletCarnet, essais: 3)",
        "sans objet": "toucher(onglet)",
    }
    admis = {
        "effet": 'app.toucher(app.elementAcces("onglet.x"), jusqua: carte)',
        "effet à la ligne": "app.toucher(\n    onglet,\n    jusqua: app.elementAcces(\"y\"))",
        "onglet dans l'effet seul": 'app.toucher(plus, jusqua: app.elementAcces("onglet.reporting"))',
        "commentaire": "// app.toucher(onglet)",
        "commentaire en fin": 'app.toucher(carte)  // puis app.toucher(onglet)',
        "pas un onglet": 'app.toucher(app.elementAcces("barre.communaute"))',
        "mot voisin": 'app.toucher(app.elementAcces("ongletsx.y"))',
        "déclaration": "func toucher(_ onglet: XCUIElement)",
        "autre fonction": "app.toucherAuDessin(onglet)",
    }
    ok = True
    for nom, code in refuses.items():
        if len(nus("a", code)) != 1:
            print(f"❌ autotest : « {nom} » n'est pas refusé")
            ok = False
    for nom, code in admis.items():
        if nus("a", code):
            print(f"❌ autotest : « {nom} » est refusé à tort")
            ok = False
    with tempfile.TemporaryDirectory() as d, contextlib.redirect_stdout(io.StringIO()):
        racine = pathlib.Path(d)
        (racine / "CoproFirstUITests").mkdir()
        f = "CoproFirstUITests/AvisReglementUITests.swift"
        (racine / f).write_text("app.toucher(onglets)\n", encoding="utf-8")
        if juger(racine, [f]) != 0:
            print("❌ autotest : l'exception déclarée n'est pas admise")
            ok = False
        (racine / f).write_text("app.toucher(onglets, jusqua: x)\n", encoding="utf-8")
        if juger(racine, [f]) != 1:
            print("❌ autotest : une exception sans emploi n'est pas refusée")
            ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    if sys.argv[1:] == ["--autotest"]:
        sys.exit(autotest())
    sys.exit(juger(pathlib.Path(__file__).resolve().parent.parent, sys.argv[1:]))
