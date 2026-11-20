#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Confidentialité déclarée = confidentialité réelle (#19, standards/14 §3 bis).

Trois textes disent ce que l'app fait des données : le manifeste embarqué
(`CoproFirst/PrivacyInfo.xcprivacy`), la fiche à saisir dans App Store Connect
(`.claude/skills/publication-app-store/confidentialite.md`) et le code. Ce juge refuse
qu'ils divergent sur ce qui se MESURE dans le dépôt, dans les deux sens (une
déclaration sans objet se retire, standards/05 §9 bis) :

  - une API « à raison requise » appelée ⇄ déclarée au manifeste, raison admise ;
  - aucun symbole de traçage ; `NSPrivacyTracking` faux, aucun domaine de traçage ;
  - chaque module importé ⇄ la table « modules » de la fiche (aucun SDK non classé) ;
  - chaque fichier qui ouvre une porte réseau ⇄ la table « portes » ;
  - chaque droit et chaque autorisation de `project.yml` ⇄ les tables de la fiche ;
  - chaque envoi (POST, PATCH, PUT, DELETE du client généré) ⇄ la table « envois », qui
    le classe dans un type de donnée du manifeste ; chaque type du manifeste ⇄ la
    table « donnees », et il est porté par un envoi au moins ;
  - chaque preuve de la fiche (`fichier` › `extrait`) se retrouve dans le fichier ;
  - la description du magasin, versionnée dans la fiche, ne nie aucun type que le
    manifeste déclare (« aucune mesure d'audience » face à `ProductInteraction`, #238) ;
  - chaque paquet de `Package.resolved` ⇄ la table « paquets », à la RÉVISION examinée ;
    ses sources, quand elles sont là, sont relues ;
  - le manifeste propre d'une cible (l'Apple TV #218, l'Apple Watch #226 :
    `confidentialite_cibles.py`) est embarqué, et juste pour le code qu'elle compile — sans
    type que le manifeste de l'app ne déclare.

Ce qui ne se mesure pas ici est dit INCONNU à chaque passage, jamais conforme. Une
entrée illisible rend INCONNU (sortie 2).

Usage : python3 scripts/verifier-confidentialite.py [--autotest]
"""

from __future__ import annotations

import importlib.util
import json
import os
import plistlib
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

RACINE = Path(__file__).resolve().parent.parent
FICHE = ".claude/skills/publication-app-store/confidentialite.md"
MANIFESTE = "CoproFirst/PrivacyInfo.xcprivacy"
RESOLU = "Paquets/ClientAPI/Package.resolved"
CONSTRUIT = "Paquets/ClientAPI/.build"
# L'écran de hall (CoproFirstTV/, #218) et l'Apple Watch (CoproFirstWatch/, #226) sont jugés
# avec l'app : même identifiant, même fiche. Chacune embarque en plus SON manifeste, jugé sur
# le code qu'elle compile (`confidentialite_cibles.py`). Le widget de la montre
# (CoproFirstWatchWidget/, #226 lot 3) est jugé avec l'app : il ne lit ni n'envoie rien.
CODE = ("CoproFirst/", "CoproFirstTV/", "CoproFirstWatch/", "CoproFirstWatchWidget/", "Paquets/ClientAPI/Sources/")
TYPE = "NSPrivacyCollectedDataType"
CATEGORIE = "NSPrivacyAccessedAPICategory"
TABLES = ("donnees", "envois", "portes", "droits", "autorisations", "modules", "paquets")
NON_MESURE = (
    "ce que chaque installation garde et journalise ; ce que la page de confidentialité du "
    "site affiche ; ce qui est saisi dans App Store Connect ; un champ neuf dans un envoi "
    "déjà classé ; ce que les cadres d'Apple transmettent")

#: La description du magasin, versionnée dans la fiche (#238), et ce qui NIERAIT un type
#: déclaré : la 1.0 disait « aucune mesure d'audience », faux dès les écrans vus (#199).
DESCRIPTION = re.compile(r"<!-- description -->(.*?)<!-- /description -->", re.S)
NEGATIONS = {
    "ProductInteraction": re.compile(
        r"\b(aucune?|sans|pas de|ni)\s+(mesure d'audience|statistiques?|analyse d'usage|suivi de l'usage)"
        r"|\bno (analytics|usage data)", re.I),
}

# Les API « à raison requise » et les raisons admises, relues le 11/11/2026 dans la
# documentation d'Apple (NSPrivacyAccessedAPIType) — à relire avant chaque soumission.
API = {
    "UserDefaults": (r"\bUserDefaults\b|@AppStorage\b", {"CA92.1", "1C8F.1", "C56D.1", "AC6B.1"}),
    "FileTimestamp": (
        r"\bcreationDate\b|\bmodificationDate\b|fileModificationDate|contentModificationDateKey|creationDateKey"
        r"|\bf?getattrlist(?:bulk|at)?\(|\b[fl]?stat(?:at)?\(",
        {"DDA9.1", "C617.1", "3B52.1", "0A2A.1"}),
    "SystemBootTime": (r"\bsystemUptime\b|\bmach_absolute_time\(", {"35F9.1", "8FFB.1", "3D61.1"}),
    "DiskSpace": (
        r"volumeAvailableCapacity\w*Key|volumeTotalCapacityKey|\bsystemFreeSize\b|\bsystemSize\b|\bf?statv?fs\(",
        {"85F4.1", "E174.1", "7D9E.1", "B728.1"}),
    "ActiveKeyboards": (r"\bactiveInputModes\b", {"3EC4.1", "54BD.1"}),
}
TRACAGE = re.compile(
    r"ATTrackingManager|AppTrackingTransparency|ASIdentifierManager|advertisingIdentifier|\bAdSupport\b"
    r"|SKAdNetwork|\bAdServices\b|AAAttribution")
# Un symbole qui trahit une donnée : il n'entre pas sans que le manifeste la déclare.
INDICES = (
    (r"PhotosPicker|PHPickerViewController|UIImagePickerController", ("PhotosorVideos",)),
    (r"CLLocationManager", ("PreciseLocation", "CoarseLocation")),
    (r"CNContactStore", ("Contacts",)),
    (r"HKHealthStore", ("Health", "Fitness")),
    (r"AVAudioRecorder|AVAudioEngine|SFSpeechRecognizer", ("AudioData",)),
    (r"MXMetricManager", ("CrashData", "PerformanceData", "OtherDiagnosticData")),
    (r"[tT]elemetryCollect", ("ProductInteraction", "OtherUsageData")),
    (r"identifierForVendor", ("DeviceID",)),
)
PORTE = re.compile(
    r"\bURLSession(?:Configuration)?\b|\bURLRequest\b|\.data\((?:from|for):|\.(?:upload|download)\((?:for|from):"
    r"|\bNWConnection\b|\bAsyncImage\b")
ENVOI = re.compile(r"\.((?:post|patch|put|delete)[A-Z][A-Za-z0-9]*)\(")
IMPORT = re.compile(
    r"^\s*(?:@\w+\s+)*import\s+(?:(?:struct|class|enum|protocol|func|var|let|typealias)\s+)?([A-Za-z_]\w*)")
PREUVE = re.compile(r"`([^`\s]+)` › `([^`]+)`")
AUTORISATION = re.compile(r"^NS\w+UsageDescription$")


def _module(nom: str, fichier: str):
    """Un script voisin, chargé : ses fonctions servent ici, jamais copiées."""
    spec = importlib.util.spec_from_file_location(nom, RACINE / "scripts" / fichier)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# La ligne sans son commentaire (verifier-simule.py) ; les manifestes propres des cibles (#218, #226).
code_seul = _module("verifier_simule", "verifier-simule.py").code_seul
CIBLES = _module("confidentialite_cibles", "confidentialite_cibles.py")


@dataclass
class Etat:
    """Ce que le juge lit — le dépôt en vrai, un jeu minimal dans l'autotest."""
    manifeste: dict
    fiche: str
    projet: str
    code: dict[str, str]  # chemin → texte : le code de l'app
    lire: Callable[[str], str | None]  # un fichier suivi, pour les preuves
    resolu: dict[str, str]  # identité du paquet → révision épinglée
    paquets: dict[str, dict[str, str]] = field(default_factory=dict)  # identité → ses sources, si là
    genere: dict[str, str] | None = None  # le client généré, s'il a été construit ici
    cibles: dict[str, dict | None] = field(default_factory=dict)  # cible → son manifeste, s'il est suivi


def tables(fiche: str) -> dict[str, list[list[str]]]:
    """`<!-- table:nom -->` puis un tableau : nom → les cellules de chaque ligne, sans l'en-tête."""
    trouvees: dict[str, list[list[str]]] = {}
    nom = None
    for ligne in fiche.splitlines():
        marque = re.match(r"<!-- table:([a-z]+) -->", ligne.strip())
        if marque:
            nom = marque.group(1)
            trouvees[nom] = []
        elif nom and ligne.startswith("|"):
            cellules = [c.strip() for c in ligne.strip().strip("|").split("|")]
            if not set(cellules[0]) <= set("-: "):
                trouvees[nom].append(cellules)
        elif nom and trouvees[nom]:
            nom = None
    return {n: lignes[1:] for n, lignes in trouvees.items()}


def jetons(cellule: str) -> list[str]:
    return re.findall(r"`([^`]+)`", cellule)


def cles_du_projet(projet: str, bloc: str) -> set[str]:
    """Les clés de `<bloc>: … properties:` dans project.yml, lues par retrait (sans PyYAML)."""
    lignes = [l for l in projet.splitlines() if l.strip() and not l.strip().startswith("#")]
    retrait = lambda l: len(l) - len(l.lstrip())  # noqa: E731
    cles: set[str] = set()
    for rang, ligne in enumerate(lignes):
        if ligne.strip() != f"{bloc}:":
            continue
        proprietes = enfant = None
        for suite in lignes[rang + 1:]:
            if retrait(suite) <= retrait(ligne):
                break
            if proprietes is None:
                proprietes = retrait(suite) if suite.strip() == "properties:" else None
                continue
            if retrait(suite) <= proprietes:
                break
            enfant = enfant or retrait(suite)
            if retrait(suite) == enfant and not suite.strip().startswith("-"):
                cles.add(suite.strip().split(":")[0].strip("\"'"))
    return cles


def trouver(motif: str | re.Pattern, code: dict[str, str]) -> dict[str, str]:
    """Ce que le motif capture (ou le fichier, sans groupe) → « chemin:ligne » de sa 1re occurrence."""
    motif = re.compile(motif) if isinstance(motif, str) else motif
    trouves: dict[str, str] = {}
    for chemin in sorted(code):
        for numero, ligne in enumerate(code[chemin].splitlines(), 1):
            for capture in motif.finditer(code_seul(ligne)):
                trouves.setdefault(capture.group(1) if motif.groups else chemin, f"{chemin}:{numero}")
    return trouves


def ecarts(quoi: str, reels: dict[str, str], declares: set[str], declare_ou: str) -> list[str]:
    """Une relation a deux sens de rupture : le réel non déclaré, le déclaré sans objet."""
    fautes = [f"{quoi} : « {x} » ({reels[x]}) n'est pas déclaré dans {declare_ou}" for x in sorted(set(reels) - declares)]
    fautes += [
        f"{quoi} : « {x} » est déclaré dans {declare_ou} mais n'existe plus — le retirer"
        for x in sorted(declares - set(reels))]
    return fautes


def juger_manifeste(manifeste: dict) -> list[str]:
    fautes = []
    if manifeste.get("NSPrivacyTracking") is not False:
        fautes.append("manifeste : NSPrivacyTracking n'est pas « false » — l'app ne trace pas")
    if manifeste.get("NSPrivacyTrackingDomains"):
        fautes.append("manifeste : NSPrivacyTrackingDomains n'est pas vide")
    noms = []
    for donnee in manifeste.get("NSPrivacyCollectedDataTypes", []):
        nom = donnee.get(TYPE, "?")
        noms.append(nom)
        if not nom.startswith(TYPE) or nom == TYPE:
            fautes.append(f"manifeste : « {nom} » n'est pas un type de donnée d'Apple")
        if donnee.get(TYPE + "Tracking") is not False:
            fautes.append(f"manifeste : {nom} est marqué pour le traçage")
        if not isinstance(donnee.get(TYPE + "Linked"), bool):
            fautes.append(f"manifeste : {nom} ne dit pas s'il est lié à la personne")
        if not donnee.get(TYPE + "Purposes"):
            fautes.append(f"manifeste : {nom} n'a aucune finalité")
    fautes += [f"manifeste : {nom} est déclaré deux fois" for nom in sorted(set(noms)) if noms.count(nom) > 1]
    return fautes


def juger_api(manifeste: dict, code: dict[str, str], ou: str = "le code de l'app", sans_objet: bool = False) -> list[str]:
    declarees = {
        acces.get("NSPrivacyAccessedAPIType", "?").removeprefix(CATEGORIE): set(
            acces.get("NSPrivacyAccessedAPITypeReasons", []))
        for acces in manifeste.get("NSPrivacyAccessedAPITypes", [])}
    appelees = {}
    for categorie, (motif, _) in API.items():
        lieu = next(iter(trouver(motif, code).values()), None)
        if lieu:
            appelees[categorie] = lieu
    fautes = [
        f"API à raison requise : {categorie} est appelée par {ou} ({lieu}) sans être déclarée au manifeste"
        for categorie, lieu in sorted(appelees.items()) if categorie not in declarees]
    fautes += [f"{chemin_ligne} : symbole de traçage dans {ou}" for chemin_ligne in trouver(TRACAGE, code).values()]
    if sans_objet:  # le code de l'app seul : un paquet n'appelle pas tout ce que l'app déclare
        fautes += [
            f"manifeste : {categorie} est déclarée, mais {ou} ne l'appelle plus — la retirer"
            for categorie in sorted(set(declarees) - set(appelees))]
    return fautes + [
        f"manifeste : {categorie} — raison absente ou hors de la liste d'Apple ({', '.join(sorted(raisons)) or 'aucune'})"
        for categorie, raisons in sorted(declarees.items())
        if not raisons or raisons - API.get(categorie, ("", set()))[1]]


def juger_paquets(etat: Etat, lignes: list[list[str]]) -> list[str]:
    """Chaque paquet épinglé est classé, à la révision examinée ; ses sources, si là, relues."""
    declares = {(jetons(l[0]) or [l[0]])[0]: l for l in lignes}
    fautes = ecarts("paquet", {i: RESOLU for i in etat.resolu}, set(declares), "la table « paquets » de la fiche")
    for identite, ligne in sorted(declares.items()):
        if identite not in etat.resolu or len(ligne) < 4:
            continue
        revision, role, dossiers = "".join(jetons(ligne[1])), ligne[2].strip("* "), jetons(ligne[3])
        if revision != etat.resolu[identite]:
            fautes.append(
                f"paquet {identite} : épinglé à {etat.resolu[identite][:12]}, examiné à {revision[:12] or '?'}"
                " — le relire, puis porter la révision dans la fiche")
        if role not in ("embarqué", "outil"):
            fautes.append(f"paquet {identite} : rôle « {role} » — « embarqué » ou « outil »")
        if role != "embarqué":
            continue
        if not dossiers:
            fautes.append(f"paquet {identite} : embarqué, sans dossier de sources examiné")
        sources = etat.paquets.get(identite)
        if sources is None:
            continue
        for dossier in dossiers:
            lues = {c: t for c, t in sources.items() if c.startswith(dossier.rstrip("/") + "/")}
            if not lues:
                fautes.append(f"paquet {identite} : « {dossier} » n'a plus de sources — le relire")
            fautes += juger_api(etat.manifeste, lues, f"le paquet {identite}")
    return fautes


def juger(etat: Etat) -> list[str]:
    lues = tables(etat.fiche)
    absentes = [n for n in TABLES if not lues.get(n)]
    if absentes:
        return [f"fiche : table(s) absente(s) ou vide(s) : {', '.join(absentes)} (<!-- table:nom -->)"]
    premiers = {n: {(jetons(l[0]) or [l[0]])[0] for l in lues[n]} for n in TABLES}
    types = types_de(etat.manifeste)
    fautes = juger_manifeste(etat.manifeste) + juger_api(etat.manifeste, etat.code, sans_objet=True)
    bloc = DESCRIPTION.search(etat.fiche)
    if bloc is None:
        fautes.append("fiche : aucun bloc <!-- description --> — la description du magasin n'est pas versionnée (#238)")
    else:
        fautes += [f"description : « {m.group(0)} » nie {TYPE}{t}, que le manifeste déclare (#238)"
                   for t, motif in NEGATIONS.items() if t in types and (m := motif.search(bloc.group(1)))]
    if etat.genere is not None:
        fautes += juger_api(etat.manifeste, etat.genere, "le client généré")
    if not re.search(r"^\s*- path: CoproFirst\s*$", etat.projet, re.M) or etat.lire(MANIFESTE) is None:
        fautes.append(f"{MANIFESTE} n'est plus dans une source de la cible (project.yml) : il n'est plus embarqué")

    fautes += ecarts("module importé", trouver(IMPORT, etat.code), premiers["modules"], "la table « modules »")
    fautes += ecarts("porte réseau", trouver(PORTE, etat.code), premiers["portes"], "la table « portes »")
    droits = {c: "project.yml" for c in cles_du_projet(etat.projet, "entitlements")}
    fautes += ecarts("droit", droits, premiers["droits"], "la table « droits »")
    autorisations = {c: "project.yml" for c in cles_du_projet(etat.projet, "info") if AUTORISATION.match(c)}
    fautes += ecarts("autorisation", autorisations, premiers["autorisations"], "la table « autorisations »")

    fautes += ecarts(
        "type de donnée", {TYPE + t: MANIFESTE for t in types}, premiers["donnees"], "la table « donnees »")
    fautes += [
        f"fiche : la réponse « {l[0]} » n'a aucune preuve (`fichier` › `extrait`)"
        for l in lues["donnees"] if not PREUVE.search(" ".join(l))]
    fautes += ecarts("envoi", trouver(ENVOI, etat.code), premiers["envois"], "la table « envois »")
    classes = classes_des_envois(lues["envois"])
    fautes += envois_et_indices(classes, etat.code, types, "le manifeste")
    portes = set().union(*classes.values())
    fautes += [f"type de donnée : {TYPE}{t} est déclaré, mais aucun envoi ne le porte" for t in sorted(types - portes)]

    for chemin, extrait in PREUVE.findall(etat.fiche):
        texte = etat.lire(chemin)
        if texte is None:
            fautes.append(f"preuve : « {chemin} » n'est pas un fichier suivi")
        elif extrait not in texte:
            fautes.append(f"preuve : « {extrait} » n'est plus dans {chemin}")
    return fautes + juger_paquets(etat, lues["paquets"]) + CIBLES.juger(etat, sys.modules[__name__], types, classes)


def types_de(manifeste: dict) -> set[str]:
    return {d.get(TYPE, "?").removeprefix(TYPE) for d in manifeste.get("NSPrivacyCollectedDataTypes", [])}


def classes_des_envois(lignes: list[list[str]]) -> dict[str, set[str]]:
    """Chaque envoi de la fiche → les types de donnée qu'il porte."""
    return {(jetons(l[0]) or [l[0]])[0]: set(jetons(l[1])) if len(l) > 1 else set() for l in lignes}


def envois_et_indices(classes: dict[str, set[str]], code: dict[str, str], types: set[str], quel: str) -> list[str]:
    """Ce que `code` envoie, et les symboles qui trahissent une donnée, déclarés par `quel`."""
    envoyes = set(trouver(ENVOI, code)) & set(classes)
    fautes = [
        f"envoi {envoi} : classé « {t} », que {quel} ne déclare pas"
        for envoi in sorted(envoyes) for t in sorted(classes[envoi] - types)]
    for motif, attendus in INDICES:
        lieu = next(iter(trouver(motif, code).values()), None)
        if lieu and not types & set(attendus):
            fautes.append(f"{lieu} : ce symbole porte une donnée ({' ou '.join(attendus)}) que {quel} ne déclare pas")
    return fautes


# ── Le dépôt ───────────────────────────────────────────────────────────────────────

def sources_du_paquet(epingle: dict) -> dict[str, str] | None:
    """Les sources du paquet, s'il est extrait ICI à la révision épinglée ; sinon `None`."""
    dossier = RACINE / CONSTRUIT / "checkouts" / epingle["location"].rstrip("/").removesuffix(".git").rsplit("/", 1)[-1]
    # Sans les GIT_* d'un hook : sous pre-commit, ils désignent CE dépôt, pas celui du paquet.
    propre = {c: v for c, v in os.environ.items() if not c.startswith("GIT_")}
    tete = subprocess.run(["git", "-C", str(dossier), "rev-parse", "HEAD"], capture_output=True, text=True, env=propre)
    if not (dossier / "Sources").is_dir() or tete.stdout.strip() != epingle["state"]["revision"]:
        return None
    return {
        f.relative_to(dossier).as_posix(): f.read_text(encoding="utf-8", errors="replace")
        for f in (dossier / "Sources").rglob("*.swift")}


def lire_le_depot() -> Etat:
    suivis = subprocess.run(
        ["git", "ls-files", "--cached"], cwd=RACINE, capture_output=True, text=True, check=True).stdout.splitlines()
    suivis = {f for f in suivis if (RACINE / f).is_file()}
    lire = lambda chemin: (RACINE / chemin).read_text(encoding="utf-8") if chemin in suivis else None  # noqa: E731
    code = {f: lire(f) for f in suivis if f.startswith(CODE) and f.endswith(".swift")}
    if not code or FICHE not in suivis:
        raise ValueError("le code de l'app ou la fiche ne sont pas suivis par git")
    epingles = json.loads(lire(RESOLU))["pins"]
    generes = list((RACINE / CONSTRUIT / "plugins").rglob("GeneratedSources/*.swift"))
    with open(RACINE / MANIFESTE, "rb") as flux:
        manifeste = plistlib.load(flux)
    return Etat(
        manifeste=manifeste, fiche=lire(FICHE), projet=lire("project.yml"), code=code, lire=lire,
        resolu={p["identity"]: p["state"]["revision"] for p in epingles},
        paquets={p["identity"]: s for p in epingles if (s := sources_du_paquet(p)) is not None},
        genere={f.name: f.read_text(encoding="utf-8") for f in generes} or None,
        cibles={c: plistlib.loads((RACINE / m).read_bytes()) if m in suivis else None for c, m in CIBLES.MANIFESTES.items()})


def main() -> int:
    if "--autotest" in sys.argv[1:]:
        spec = importlib.util.spec_from_file_location("autotest", RACINE / "scripts/confidentialite_autotest.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return 0 if module.autotest(sys.modules[__name__]) else 1
    try:
        etat = lire_le_depot()
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError, plistlib.InvalidFileException) as erreur:
        print(f"❓ INCONNU : manifeste, fiche ou dépôt illisible — {erreur}")
        return 2
    fautes = juger(etat)
    for faute in fautes:
        print(f"❌ {faute}")
    if fautes:
        print(f"── manifeste : {MANIFESTE} ; fiche : {FICHE}")
        return 1
    lues = tables(etat.fiche)
    embarques = [l for l in lues["paquets"] if l[2].strip("* ") == "embarqué"]
    relus = sum(1 for l in embarques if jetons(l[0])[0] in etat.paquets)
    print(
        f"✅ confidentialité déclarée = code : {len(lues['donnees'])} types de données, {len(lues['envois'])} envois"
        f" classés, {len(lues['portes'])} portes réseau, {len(lues['modules'])} modules, {len(lues['paquets'])} paquets"
        f" à la révision examinée (sources relues ici : {relus}/{len(embarques)} ; client généré :"
        f" {'relu' if etat.genere else 'non construit ici'} ; manifestes propres : {', '.join(CIBLES.MANIFESTES)})")
    print(f"❓ INCONNU, non mesuré ici : {NON_MESURE}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
