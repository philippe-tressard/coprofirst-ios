#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les tables de la Communauté et du Profil, GÉNÉRÉES depuis coprofirst (#14).

Le contrat d'API ne sert que des CODES : libellés, teintes et seuils vivent dans le
code de coprofirst. Rien ne se recopie à la main (garde-fou de `projets.json`).
Quand une règle vit des deux côtés, la source est le SERVEUR — c'est lui qui juge :

- idées : `STATUTS_IDEE` (`front/src/lib/idees.ts`) ;
- annonces : `TYPES_ANNONCE`, `CATEGORIES_ANNONCE`, `TRIS_ANNONCE`, `STATUTS_ANNONCE`
  et la teinte de chaque statut (`statutAnnonceClass`, `front/src/lib/annonces.ts`) ;
- avis : les bornes et les seuils de la note (`api/app/utils/avis.py`, serveur) ;
- thème : `OPTIONS_THEME`, `COOKIE_THEME`, `THEME_PAR_DEFAUT` (`front/src/lib/theme.ts`) ;
- préférences de notification : les défauts (`DEFAUTS`, `api/app/utils/preferences_mail.py`,
  serveur) et les deux canaux (`CANAUX_NOTIFS`, `front/src/lib/preferences.ts`) ;
- profils demandables (`STATUTS_DEMANDABLES`, `front/src/lib/roles.ts`) ;
- longueur minimale d'un mot de passe (`verifier_robustesse`, `api/app/utils/mots_de_passe.py`).

Sorties, dans les dossiers des menus — aucune session parallèle n'y touche :
`CoproFirst/Fonctions/Communaute/Genere/TablesCommunaute.swift` et
`CoproFirst/Fonctions/Profil/Genere/TablesProfil.swift`. Script à part de
`generer-charte.py` (#14, en attendant `scripts/generateurs/`).

Usage : python3 scripts/generer-communaute-profil.py [chemin/vers/coprofirst]
"""

from __future__ import annotations

import os
import pathlib
import re
import subprocess
import sys

import lecture_ts

RACINE = pathlib.Path(__file__).resolve().parents[1]
COPROFIRST = pathlib.Path(
    sys.argv[1] if len(sys.argv) > 1 else os.environ.get("COPROFIRST_RACINE", "/Volumes/Data/Dev/5hostachy"))
LIB = COPROFIRST / "front" / "src" / "lib"
API = COPROFIRST / "api" / "app" / "utils"
SORTIE_COMMUNAUTE = RACINE / "CoproFirst" / "Fonctions" / "Communaute" / "Genere" / "TablesCommunaute.swift"
SORTIE_PROFIL = RACINE / "CoproFirst" / "Fonctions" / "Profil" / "Genere" / "TablesProfil.swift"


def lire(chemin: pathlib.Path) -> str:
    return chemin.read_text(encoding="utf-8")


def chaine(valeur) -> str:
    texte = str(valeur).replace("\\", "\\\\").replace('"', '\\"')
    return f'"{texte}"'


def entier(texte: str, motif: str, source: str) -> int:
    m = re.search(motif, texte)
    if not m:
        raise SystemExit(f"❌ {source} : « {motif} » introuvable — la source a changé")
    return int(m.group(1))


def chaine_ts(texte: str, nom: str) -> str:
    m = re.search(rf"\bconst {nom}\b[^=]*=\s*'([^']*)'", texte)
    if not m:
        raise SystemExit(f"❌ {nom} introuvable")
    return m.group(1)


def teintes_annonce(texte: str) -> dict[str, str]:
    """Le dictionnaire littéral de `statutAnnonceClass` : statut → `badge-*`."""
    corps = texte[texte.index("function statutAnnonceClass"):]
    corps = corps[: corps.index("}", corps.index("badge-")) + 1]
    return dict(re.findall(r"(\w+):\s*'(badge-[a-z]+)'", corps))


def defauts_preferences(texte: str) -> dict[str, bool]:
    """`DEFAUTS` du serveur, ses clés résolues par les constantes du module."""
    constantes = dict(re.findall(r'^([A-Z_]+)\s*=\s*"([a-z_]+)"', texte, re.M))
    corps = re.search(r"^DEFAUTS[^=]*=\s*\{(.*?)\}", texte, re.S | re.M)
    if not corps:
        raise SystemExit("❌ DEFAUTS introuvable dans preferences_mail.py")
    paires = re.findall(r"([A-Z_]+):\s*(True|False)", corps.group(1))
    if not paires:
        raise SystemExit("❌ DEFAUTS vide ou illisible")
    return {constantes[nom]: valeur == "True" for nom, valeur in paires}


def commit() -> str:
    return subprocess.run(
        ["git", "-C", str(COPROFIRST), "rev-parse", "--short=9", "HEAD"], capture_output=True, text=True, check=True
    ).stdout.strip()


# L'en-tête que le script ÉCRIT dans le fichier généré : une chaîne, pas la
# déclaration de ce script — REUSE ne doit pas la lire.
# REUSE-IgnoreStart
def entete(source: str) -> str:
    return (
        "// SPDX-FileCopyrightText: 2026 Philippe TRESSARD\n"
        "// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore\n"
        "//\n"
        "// GÉNÉRÉ par scripts/generer-communaute-profil.py — NE PAS MODIFIER À LA MAIN.\n"
        "// swift-format-ignore-file\n"
        f"// Source : coprofirst@{commit()}, {source}.\n\n"
    )
# REUSE-IgnoreEnd


def element(type_: str, **champs) -> str:
    """Un élément de tableau Swift ; au-delà de 120 colonnes, un argument par ligne."""
    arguments = [f"{nom}: {chaine(valeur)}" for nom, valeur in champs.items()]
    ligne = f"        {type_}({', '.join(arguments)}),\n"
    if len(ligne) <= 121:
        return ligne
    return f"        {type_}(\n" + "".join(f"            {a},\n" for a in arguments[:-1]) + (
        f"            {arguments[-1]}),\n")


def statut(code: str, libelle: str, pastille: str) -> str:
    return element("EntreeStatut", code=code, libelle=libelle, pastille=pastille)


def libelles(table: list, cle: str = "val") -> str:
    return "".join(f"        ({chaine(e[cle])}, {chaine(e['label'])}),\n" for e in table)


def communaute() -> str:
    idees = lire(LIB / "idees.ts")
    annonces = lire(LIB / "annonces.ts")
    avis = lire(API / "avis.py")
    teintes = teintes_annonce(annonces)
    statuts_annonce = lecture_ts.table(annonces, "STATUTS_ANNONCE")
    manquantes = [s["val"] for s in statuts_annonce if s["val"] not in teintes]
    if manquantes:
        raise SystemExit(f"❌ statutAnnonceClass ne teinte pas : {manquantes}")
    return (
        entete("front/src/lib/idees.ts et annonces.ts ; api/app/utils/avis.py")
        + "/// Ce que le site écrit de la Communauté et que le contrat ne sert pas.\n"
        "enum TablesCommunaute {\n"
        "    /// Les états d'une idée, dans l'ordre du cycle de vie (`STATUTS_IDEE`).\n"
        "    static let statutsIdee: [EntreeStatut] = [\n"
        + "".join(statut(s["value"], s["label"], s["badge"]) for s in lecture_ts.table(idees, "STATUTS_IDEE"))
        + "    ]\n"
        "    /// Les types d'annonce (`TYPES_ANNONCE`).\n"
        "    static let typesAnnonce: [(code: String, libelle: String)] = [\n"
        + libelles(lecture_ts.table(annonces, "TYPES_ANNONCE"))
        + "    ]\n"
        "    /// Les catégories d'annonce (`CATEGORIES_ANNONCE`).\n"
        "    static let categoriesAnnonce: [(code: String, libelle: String)] = [\n"
        + libelles(lecture_ts.table(annonces, "CATEGORIES_ANNONCE"))
        + "    ]\n"
        "    /// Les tris des annonces (`TRIS_ANNONCE`).\n"
        "    static let trisAnnonce: [(code: String, libelle: String)] = [\n"
        + libelles(lecture_ts.table(annonces, "TRIS_ANNONCE"))
        + "    ]\n"
        "    /// Les états d'une annonce et leur teinte (`STATUTS_ANNONCE`, `statutAnnonceClass`).\n"
        "    static let statutsAnnonce: [EntreeStatut] = [\n"
        + "".join(statut(s["val"], s["label"], teintes[s["val"]]) for s in statuts_annonce)
        + "    ]\n"
        "    /// La note d'un avis et ses seuils — la règle du SERVEUR (`utils/avis.py`) :\n"
        "    /// sous `noteRemarque`, ce qui a manqué ; à partir de `notePubliable`, l'accord de diffusion.\n"
        f"    static let noteMin = {entier(avis, r'(?m)^NOTE_MIN\s*=\s*(\d+)', 'avis.py')}\n"
        f"    static let noteMax = {entier(avis, r'(?m)^NOTE_MAX\s*=\s*(\d+)', 'avis.py')}\n"
        f"    static let noteRemarque = {entier(avis, r'(?m)^NOTE_REMARQUE\s*=\s*(\d+)', 'avis.py')}\n"
        f"    static let notePubliable = {entier(avis, r'(?m)^NOTE_PUBLIABLE\s*=\s*(\d+)', 'avis.py')}\n"
        "}\n"
    )


def profil() -> str:
    theme = lire(LIB / "theme.ts")
    preferences = lire(LIB / "preferences.ts")
    constantes = dict(re.findall(r"\bconst ([A-Z_]+)\s*=\s*'([a-z_]+)'", preferences))
    defauts = defauts_preferences(lire(API / "preferences_mail.py"))
    canaux = lecture_ts.table(preferences, "CANAUX_NOTIFS")
    for canal in canaux:
        for cle in ("mon", "autres"):
            canal[cle] = constantes.get(str(canal[cle]), str(canal[cle]))
            if canal[cle] not in defauts:
                raise SystemExit(f"❌ CANAUX_NOTIFS : {canal[cle]} n'a pas de défaut côté serveur")
    longueur = entier(lire(API / "mots_de_passe.py"), r"len\(password\)\s*<\s*(\d+)", "mots_de_passe.py")
    return (
        entete(
            "front/src/lib/theme.ts, preferences.ts et roles.ts ; "
            "api/app/utils/preferences_mail.py et mots_de_passe.py")
        + "/// Ce que le site écrit du Profil et que le contrat ne sert pas.\n"
        "enum TablesProfil {\n"
        "    /// Le thème : une préférence de l'APPAREIL (le cookie du site), ses choix (`OPTIONS_THEME`).\n"
        f"    static let cleTheme = {chaine(chaine_ts(theme, 'COOKIE_THEME'))}\n"
        f"    static let themeParDefaut = {chaine(chaine_ts(theme, 'THEME_PAR_DEFAUT'))}\n"
        "    static let optionsTheme: [OptionTheme] = [\n"
        + "".join(
            element("OptionTheme", code=o["val"], libelle=o["label"], detail=o["desc"])
            for o in lecture_ts.table(theme, "OPTIONS_THEME"))
        + "    ]\n"
        "    /// Les défauts d'une préférence jamais réglée — ceux du SERVEUR (`DEFAUTS`).\n"
        "    static let defautsPreferences: [String: Bool] = [\n"
        + "".join(f"        {chaine(cle)}: {'true' if v else 'false'},\n" for cle, v in defauts.items())
        + "    ]\n"
        "    /// Les deux canaux et leurs deux cases (`CANAUX_NOTIFS`).\n"
        "    static let canauxNotifications: [CanalNotifications] = [\n"
        + "".join(element("CanalNotifications", titre=c["titre"], mon=c["mon"], autres=c["autres"]) for c in canaux)
        + "    ]\n"
        "    /// Les profils qu'on peut demander depuis son profil (`STATUTS_DEMANDABLES`).\n"
        "    static let statutsDemandables: [String] = [\n"
        + "".join(f"        {chaine(s)},\n" for s in lecture_ts.table(lire(LIB / "roles.ts"), "STATUTS_DEMANDABLES"))
        + "    ]\n"
        "    /// La longueur minimale d'un nouveau mot de passe (`verifier_robustesse`, serveur).\n"
        f"    static let longueurMinimaleMotDePasse = {longueur}\n"
        "}\n"
    )


def ecrire(chemin: pathlib.Path, texte: str) -> None:
    chemin.parent.mkdir(parents=True, exist_ok=True)
    chemin.write_text(texte, encoding="utf-8", newline="\n")
    print(f"✅ {chemin.relative_to(RACINE)}")


def main() -> None:
    ecrire(SORTIE_COMMUNAUTE, communaute())
    ecrire(SORTIE_PROFIL, profil())


if __name__ == "__main__":
    main()
