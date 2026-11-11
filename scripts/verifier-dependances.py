#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""DEPENDANCES.md dit ce que Package.resolved épingle (#143).

Le 11/11/2026, l'inventaire avait divergé sans que rien ne le dise : `swift-collections`,
lié à l'app par `swift-openapi-urlsession`, n'était listé que parmi les outils, et deux
versions écrites retardaient d'un correctif sur `Paquets/ClientAPI/Package.swift`.

Ce contrôle tient l'inventaire à deux sources qui, elles, sont déjà tenues :
  - la table « paquets » de la fiche de confidentialité
    (`.claude/skills/publication-app-store/confidentialite.md`), que
    `scripts/verifier-confidentialite.py` tient à `Package.resolved` ;
  - `Paquets/ClientAPI/Package.resolved` lui-même.

Il exige :
  1. chaque paquet « embarqué » de la fiche figure dans « Embarquées dans
     l'application » de DEPENDANCES.md ;
  2. un paquet épinglé que cette section liste est « embarqué » dans la fiche
     (un outil de construction n'y a pas sa place) ;
  3. une version écrite en chiffres, dans l'une ou l'autre section, est celle de
     `Package.resolved` ; « transitive », `outillage.env` ou un autre renvoi restent permis.

La forme du tableau ne change pas : `scripts/verifier-app-ios.py` de coprofirst-site
lit sa colonne « Licence ».

Usage :
  python3 scripts/verifier-dependances.py            juge le dépôt
  python3 scripts/verifier-dependances.py --autotest prouve qu'il refuse et accepte

Sortie : 0 conforme, 1 écart, 2 INCONNU (fichier, section ou tableau illisible).
"""

from __future__ import annotations

import json
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parents[1]
DEPENDANCES = "DEPENDANCES.md"
FICHE = ".claude/skills/publication-app-store/confidentialite.md"
RESOLU = "Paquets/ClientAPI/Package.resolved"
EMBARQUEES = "Embarquées dans l'application"
OUTILS = "Outils de construction (non embarqués)"

CONFORME, ECART, INCONNU = 0, 1, 2
VERSION = re.compile(r"^\d+\.\d+(\.\d+)?$")
#: `apple/swift-openapi-runtime` → `swift-openapi-runtime` : le premier dépôt nommé.
DEPOT = re.compile(r"\b[\w.-]+/([\w.-]+)")


class Illisible(Exception):
    """Ce qui empêche de juger : INCONNU, jamais conforme."""


def cellules(lignes: list[str]) -> list[list[str]]:
    """Les lignes d'un tableau Markdown, sans l'en-tête ni le séparateur."""
    rangs = [[c.strip() for c in l.strip().split("|")[1:-1]] for l in lignes if l.strip().startswith("|")]
    return rangs[2:]


def section(texte: str, titre: str) -> tuple[list[str], list[list[str]]]:
    """L'en-tête et les lignes du premier tableau sous `## titre`."""
    bloc = re.search(rf"^## {re.escape(titre)}\n(.*?)(?=^## |\Z)", texte, re.M | re.S)
    if not bloc:
        raise Illisible(f"{DEPENDANCES} : section « {titre} » introuvable")
    lignes = [l for l in bloc.group(1).splitlines() if l.strip().startswith("|")]
    if len(lignes) < 3:
        raise Illisible(f"{DEPENDANCES} : tableau de « {titre} » vide ou illisible")
    entete = [c.strip() for c in lignes[0].strip().split("|")[1:-1]]
    return entete, cellules(lignes)


def identite(cellule: str) -> str | None:
    trouve = DEPOT.search(cellule.replace("`", ""))
    return trouve.group(1).lower().removesuffix(".git") if trouve else None


def fiche_embarques(texte: str) -> set[str]:
    bloc = re.search(r"<!-- table:paquets -->\n(.*?)(?:\n\s*\n|\Z)", texte, re.S)
    if not bloc:
        raise Illisible(f"{FICHE} : table « paquets » introuvable")
    rangs = cellules(bloc.group(1).splitlines())
    if not rangs:
        raise Illisible(f"{FICHE} : table « paquets » vide")
    return {r[0].strip("` ").lower() for r in rangs if len(r) > 2 and r[2].strip("* ") == "embarqué"}


def epingles(texte: str) -> dict[str, str | None]:
    try:
        pins = json.loads(texte)["pins"]
        return {p["identity"].lower(): p["state"].get("version") for p in pins}
    except (ValueError, KeyError, TypeError) as erreur:
        raise Illisible(f"{RESOLU} illisible ({erreur})") from erreur


def juger(dependances: str, fiche: str, resolu: str) -> tuple[list[str], str]:
    """Rend les écarts et le bilan ; lève Illisible si l'on ne peut pas juger."""
    embarques, pins = fiche_embarques(fiche), epingles(resolu)
    fautes: list[str] = []
    listes: dict[str, set[str]] = {}
    versions = 0
    for titre in (EMBARQUEES, OUTILS):
        entete, rangs = section(dependances, titre)
        if "Version" not in entete:
            raise Illisible(f"{DEPENDANCES} : colonne « Version » absente de « {titre} » (forme changée ?)")
        rang_version = entete.index("Version")
        listes[titre] = set()
        for rang in rangs:
            nom = identite(rang[0]) if rang else None
            if nom is None or nom not in pins:
                continue
            listes[titre].add(nom)
            ecrite = rang[rang_version].strip("` ") if len(rang) > rang_version else ""
            if VERSION.match(ecrite):
                versions += 1
                if ecrite != pins[nom]:
                    fautes.append(f"{DEPENDANCES} : {nom} écrit {ecrite}, {RESOLU} épingle {pins[nom] or '(sans version)'}")
    for nom in sorted(embarques - listes[EMBARQUEES]):
        fautes.append(f"{DEPENDANCES} : {nom} est embarqué (fiche) mais absent de « {EMBARQUEES} »")
    for nom in sorted(listes[EMBARQUEES] - embarques):
        fautes.append(f"{DEPENDANCES} : {nom} est listé embarqué, la fiche le classe outil — le déplacer ou relire la fiche")
    bilan = f"dépendances : {len(embarques)} paquets embarqués listés, {versions} versions = {RESOLU.split('/')[-1]}"
    return fautes, bilan


def autotest() -> bool:
    deps = (
        "# Dépendances\n\n## Embarquées dans l'application\n\n| Paquet | Version | Licence | Rôle |\n|---|---|---|---|\n"
        "| apple/p-runtime | 1.2.3 | Apache-2.0 | types |\n| apple/p-collections (un module) | transitive | Apache-2.0 | file |\n"
        "| Dessins (via `icones.json`) | celle du plancher | ISC | pictogrammes |\n\n"
        "## Outils de construction (non embarqués)\n\n| Outil | Version | Licence |\n|---|---|---|\n"
        "| apple/p-generateur (greffon) et ses dépendances (p-outil…) | 4.5.6 | Apache-2.0 |\n| XcodeGen | `outillage.env` | MIT |\n")
    fiche = (
        "<!-- table:paquets -->\n| Paquet | Révision | Rôle | Sources |\n|---|---|---|---|\n"
        "| `p-runtime` | `a` | embarqué | `S/R` |\n| `p-collections` | `b` | embarqué | `S/C` |\n"
        "| `p-generateur` | `c` | outil | — |\n\nSuite.\n")
    resolu = json.dumps({"pins": [
        {"identity": "p-runtime", "state": {"version": "1.2.3", "revision": "a"}},
        {"identity": "p-collections", "state": {"version": "9.9.9", "revision": "b"}},
        {"identity": "p-generateur", "state": {"version": "4.5.6", "revision": "c"}}]})
    cas = [
        ("conforme", deps, fiche, resolu, CONFORME),
        ("version en retard", deps.replace("| 1.2.3 |", "| 1.2.2 |"), fiche, resolu, ECART),
        ("version d'outil en retard", deps.replace("| 4.5.6 |", "| 4.5.5 |"), fiche, resolu, ECART),
        ("embarqué absent", deps.replace("| apple/p-collections (un module) | transitive | Apache-2.0 | file |\n", ""),
         fiche, resolu, ECART),
        ("outil listé embarqué", deps.replace("| apple/p-runtime |", "| apple/p-generateur |"), fiche, resolu, ECART),
        ("section absente", deps.replace("## Embarquées dans l'application", "## Autre"), fiche, resolu, INCONNU),
        ("colonne Version absente", deps.replace("| Paquet | Version |", "| Paquet | Révision |"), fiche, resolu, INCONNU),
        ("table de la fiche absente", deps, fiche.replace("<!-- table:paquets -->", ""), resolu, INCONNU),
        ("Package.resolved illisible", deps, fiche, "{", INCONNU),
    ]
    reussi = True
    for nom, d, f, r, attendu in cas:
        try:
            fautes, _ = juger(d, f, r)
            obtenu = ECART if fautes else CONFORME
        except Illisible:
            obtenu = INCONNU
        if obtenu != attendu:
            print(f"❌ autotest « {nom} » : attendu {attendu}, obtenu {obtenu}")
            reussi = False
    return reussi


def main(arguments: list[str]) -> int:
    if arguments == ["--autotest"]:
        if not autotest():
            return ECART
        print("✅ autotest de verifier-dependances.py : refuse et accepte comme prévu")
        return CONFORME
    if arguments:
        print(__doc__)
        return INCONNU
    try:
        textes = [(RACINE / chemin).read_text(encoding="utf-8") for chemin in (DEPENDANCES, FICHE, RESOLU)]
        fautes, bilan = juger(*textes)
    except (OSError, Illisible) as erreur:
        print(f"❓ INCONNU : {erreur}")
        return INCONNU
    for faute in fautes:
        print(f"❌ {faute}")
    if fautes:
        return ECART
    print(f"✅ {bilan}")
    return CONFORME


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
