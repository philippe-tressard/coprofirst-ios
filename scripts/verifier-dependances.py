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

Et, depuis #168, que ce que l'app embarque d'autrui y soit accompagné de ses textes
(`standards/14` §6.1 : l'avis et la licence suivent chaque copie) :
  4. chaque licence de la colonne « Licence » des embarquées a son texte dans `LICENSES/` ;
  5. chaque paquet embarqué est nommé dans l'écran « À propos › Composants tiers »
     (`CoproFirst/Fonctions/APropos/ComposantsTiers.swift`) ;
  6. un avis (`CoproFirst/Ressources/AvisTiers/NOTICE-<paquet>.txt`) est celui d'un paquet
     embarqué que l'écran déclare `avis: true`, et réciproquement ;
  7. quand les sources du paquet sont extraites ici à la révision épinglée, l'avis recopié
     est le leur à l'octet, et un paquet qui en porte un a le sien dans l'app. Sinon :
     dit « non relu ici », jamais conforme.

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
import os
import re
import subprocess
import sys

RACINE = pathlib.Path(__file__).resolve().parents[1]
DEPENDANCES = "DEPENDANCES.md"
FICHE = ".claude/skills/publication-app-store/confidentialite.md"
RESOLU = "Paquets/ClientAPI/Package.resolved"
EMBARQUEES = "Embarquées dans l'application"
OUTILS = "Outils de construction (non embarqués)"
ECRAN = "CoproFirst/Fonctions/APropos/ComposantsTiers.swift"
AVIS = "CoproFirst/Ressources/AvisTiers"
CONSTRUIT = "Paquets/ClientAPI/.build"
#: `paquet("swift-http-types", role: "…", avis: true)` → (nom, avis).
PAQUET = re.compile(r'paquet\(\s*"([\w.-]+)"[^)]*?avis:\s*(true|false)')
#: « ISC, MIT (part issue de Feather) » → ISC, MIT : l'identifiant SPDX en tête de chaque part.
LICENCE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.+-]*")

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


def juger_textes(
    dependances: str, resolu: str, ecran: str, licences: set[str], avis: dict[str, str],
    sources: dict[str, str | None] | None = None,
) -> tuple[list[str], str]:
    """Les textes qui accompagnent ce que l'app embarque (4 à 7).

    `licences` : les identifiants de `LICENSES/` ; `avis` : paquet → avis recopié dans
    l'app ; `sources` : paquet → son NOTICE à la révision épinglée (`None` : il n'en a
    pas), pour les seuls paquets dont les sources sont extraites ici.
    """
    pins, sources = epingles(resolu), sources or {}
    entete, rangs = section(dependances, EMBARQUEES)
    if "Licence" not in entete:
        raise Illisible(f"{DEPENDANCES} : colonne « Licence » absente de « {EMBARQUEES} » (forme changée ?)")
    declares = dict(PAQUET.findall(ecran))
    if not declares:
        raise Illisible(f"{ECRAN} : aucun `paquet(\"…\", …, avis: …)` lu (forme changée ?)")
    fautes: list[str] = []
    embarques: set[str] = set()
    for rang in rangs:
        for part in rang[entete.index("Licence")].split(","):
            lue = LICENCE.match(part.strip())
            if lue and lue.group(0) not in licences:
                fautes.append(f"LICENSES/{lue.group(0)}.txt manque : {rang[0]} est embarqué sous cette licence")
        nom = identite(rang[0])
        if nom in pins:
            embarques.add(nom)
    for nom in sorted(embarques - set(declares)):
        fautes.append(f"{ECRAN} : {nom} est embarqué, « Composants tiers » ne le nomme pas")
    for nom in sorted(set(declares) - embarques):
        fautes.append(f"{ECRAN} : {nom} n'est pas un paquet embarqué de {DEPENDANCES}")
    for nom in sorted(set(avis) | {n for n, a in declares.items() if a == "true"}):
        if nom not in avis:
            fautes.append(f"{AVIS}/NOTICE-{nom}.txt manque : l'écran le déclare `avis: true`")
        elif declares.get(nom) != "true":
            fautes.append(f"{AVIS}/NOTICE-{nom}.txt : aucun paquet de l'écran ne l'affiche (`avis: true`)")
    for nom in sorted(embarques & set(sources)):
        if sources[nom] is None and nom in avis:
            fautes.append(f"{AVIS}/NOTICE-{nom}.txt : le paquet n'a pas de NOTICE à la révision épinglée")
        elif sources[nom] is not None and avis.get(nom) != sources[nom]:
            fautes.append(f"{AVIS}/NOTICE-{nom}.txt n'est pas le NOTICE.txt du paquet à la révision épinglée")
    relus = len(embarques & set(sources))
    return fautes, f"textes des composants tiers : {len(embarques)} paquets nommés à l'écran, {len(avis)} avis (relus aux sources ici : {relus}/{len(embarques)})"


def lire_les_textes() -> tuple[str, set[str], dict[str, str], dict[str, str | None]]:
    """L'écran, les licences, les avis recopiés, et les NOTICE des sources extraites ici."""
    ecran = (RACINE / ECRAN).read_text(encoding="utf-8")
    licences = {f.stem for f in (RACINE / "LICENSES").glob("*.txt")}
    avis = {f.stem.removeprefix("NOTICE-"): f.read_text(encoding="utf-8") for f in (RACINE / AVIS).glob("NOTICE-*.txt")}
    # Sans les GIT_* d'un hook : sous pre-commit, ils désignent CE dépôt, pas celui du paquet.
    propre = {c: v for c, v in os.environ.items() if not c.startswith("GIT_")}
    sources: dict[str, str | None] = {}
    for epingle in json.loads((RACINE / RESOLU).read_text(encoding="utf-8"))["pins"]:
        dossier = RACINE / CONSTRUIT / "checkouts" / epingle["location"].rstrip("/").removesuffix(".git").rsplit("/", 1)[-1]
        tete = subprocess.run(["git", "-C", str(dossier), "rev-parse", "HEAD"], capture_output=True, text=True, env=propre)
        if dossier.is_dir() and tete.stdout.strip() == epingle["state"]["revision"]:
            notice = dossier / "NOTICE.txt"
            sources[epingle["identity"].lower()] = notice.read_text(encoding="utf-8") if notice.is_file() else None
    return ecran, licences, avis, sources


def autotest_textes(deps: str, resolu: str) -> bool:
    ecran = 'paquet("p-runtime", role: "Types.", avis: true),\n paquet("p-collections", role: "File.", avis: false),'
    licences, avis = {"Apache-2.0", "ISC"}, {"p-runtime": "avis"}
    cas = [
        ("conforme", {}, CONFORME),
        ("conforme, sources relues", {"sources": {"p-runtime": "avis", "p-collections": None}}, CONFORME),
        ("licence sans texte", {"licences": {"ISC"}}, ECART),
        ("paquet embarqué non nommé", {"ecran": ecran.replace("p-collections", "p-autre")}, ECART),
        ("avis déclaré, fichier absent", {"avis": {}}, ECART),
        ("avis que rien n'affiche", {"avis": {"p-runtime": "avis", "p-collections": "x"}}, ECART),
        ("avis modifié", {"sources": {"p-runtime": "autre"}}, ECART),
        ("avis manquant, le paquet en porte un", {"sources": {"p-collections": "avis"}}, ECART),
        ("avis inventé", {"sources": {"p-runtime": None}}, ECART),
        ("écran illisible", {"ecran": "rien"}, INCONNU),
        ("colonne Licence absente", {"deps": deps.replace("| Licence | Rôle |", "| Droits | Rôle |")}, INCONNU),
    ]
    reussi = True
    for nom, change, attendu in cas:
        jeu = {"deps": deps, "ecran": ecran, "licences": licences, "avis": avis, "sources": None} | change
        try:
            fautes, _ = juger_textes(jeu["deps"], resolu, jeu["ecran"], jeu["licences"], jeu["avis"], jeu["sources"])
            obtenu = ECART if fautes else CONFORME
        except Illisible:
            obtenu = INCONNU
        if obtenu != attendu:
            print(f"❌ autotest des textes « {nom} » : attendu {attendu}, obtenu {obtenu}")
            reussi = False
    return reussi


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
    return autotest_textes(deps, resolu) and reussi


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
        fautes_textes, bilan_textes = juger_textes(textes[0], textes[2], *lire_les_textes())
        fautes, bilan = fautes + fautes_textes, f"{bilan} ; {bilan_textes}"
    except (OSError, ValueError, KeyError, Illisible) as erreur:
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
