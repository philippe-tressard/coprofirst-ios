# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Le manifeste de confidentialité de l'APPLE WATCH (#226), jugé par
`verifier-confidentialite.py` — qui le charge, comme il charge `verifier-simule.py`.

L'app montre a son paquet, donc son manifeste (`CoproFirstWatch/PrivacyInfo.xcprivacy`).
La fiche, elle, est celle de l'app : App Store Connect ne connaît qu'une fiche par app,
iPhone et montre ensemble. Ce module refuse que la montre :

  - trace, ou déclare un type mal formé (les règles de l'app, `juger_manifeste`) ;
  - appelle une API « à raison requise » — dans SON code, celui que compile sa cible
    (`project.yml`, partages nommés compris) ou dans les paquets embarqués — sans la
    déclarer, ou en déclare une qu'elle n'appelle plus (`juger_api`) ;
  - déclare un type de donnée que le manifeste de l'app, donc la fiche, ne déclare pas ;
  - ne porte pas son manifeste (absent, ou hors des sources de la cible).
"""

from __future__ import annotations

import re
from typing import Callable

MANIFESTE = "CoproFirstWatch/PrivacyInfo.xcprivacy"
CIBLE = "CoproFirstWatch"
TYPE = "NSPrivacyCollectedDataType"


def sources(projet: str, cible: str = CIBLE) -> list[str]:
    """Les `- path:` des sources de la cible, lus par retrait (sans PyYAML)."""
    lignes = [l for l in projet.splitlines() if l.strip() and not l.strip().startswith("#")]
    retrait = lambda l: len(l) - len(l.lstrip())  # noqa: E731
    debut = next((r for r, l in enumerate(lignes) if l.strip() == f"{cible}:" and retrait(l) == 2), None)
    if debut is None:
        return []
    chemins, dans_sources = [], False
    for ligne in lignes[debut + 1:]:
        if retrait(ligne) <= 2:
            break
        if retrait(ligne) == 4:
            dans_sources = ligne.strip() == "sources:"
        elif dans_sources and (m := re.match(r"-\s*path:\s*(\S+)", ligne.strip())):
            chemins.append(m.group(1))
    return chemins


def code_de_la_cible(code: dict[str, str], projet: str) -> dict[str, str]:
    """Le code de l'app que compile la cible : un dossier source, ou un fichier nommé."""
    racines = sources(projet)
    return {c: t for c, t in code.items() if any(c == r or c.startswith(r.rstrip("/") + "/") for r in racines)}


def _types(manifeste: dict) -> set[str]:
    return {d.get(TYPE, "?") for d in manifeste.get(TYPE + "s", [])}


def juger(etat, juger_manifeste: Callable, juger_api: Callable) -> list[str]:
    if etat.lire(MANIFESTE) is None:
        return [f"{MANIFESTE} est absent : l'app montre a son paquet, donc son manifeste (#226)"]
    montre = etat.montre
    fautes = [f.replace("manifeste :", "manifeste de la montre :", 1) for f in juger_manifeste(montre)]
    fautes += juger_api(montre, code_de_la_cible(etat.code, etat.projet), "le code de la montre", sans_objet=True)
    for identite, lues in sorted(etat.paquets.items()):
        fautes += juger_api(montre, lues, f"le paquet {identite}, embarqué dans la montre")
    fautes += [
        f"manifeste de la montre : {t} n'est pas déclaré par l'app — la fiche (une par app) ne le dit pas"
        for t in sorted(_types(montre) - _types(etat.manifeste))]
    if CIBLE not in sources(etat.projet):
        fautes.append(f"{MANIFESTE} n'est plus dans une source de la cible {CIBLE} : il n'est plus embarqué")
    return fautes


def preparer_jeu(etat) -> None:
    """Le jeu conforme de l'autotest, complété d'une montre conforme."""
    etat.projet += "  CoproFirstWatch:\n    sources:\n      - path: CoproFirstWatch\n      - path: CoproFirst/A.swift\n"
    etat.code["CoproFirstWatch/M.swift"] = "import Foundation\nlet m = 1\n"
    etat.montre = {
        "NSPrivacyTracking": False, "NSPrivacyTrackingDomains": [],
        TYPE + "s": [dict(etat.manifeste[TYPE + "s"][0])],
        "NSPrivacyAccessedAPITypes": [dict(etat.manifeste["NSPrivacyAccessedAPITypes"][0])]}
    lire = etat.lire
    etat.lire = lambda chemin: "<plist/>" if chemin == MANIFESTE else lire(chemin)


#: Les ruptures que l'autotest de `verifier-confidentialite.py` doit voir refusées.
RUPTURES: list[tuple[str, Callable]] = [
    ("manifeste de la montre : NSPrivacyTracking", lambda e: e.montre.update(NSPrivacyTracking=True)),
    ("FileTimestamp est appelée par le code de la montre", lambda e: e.code.update(
        {"CoproFirstWatch/M.swift": "let d = valeurs.creationDate\n"})),
    ("UserDefaults est déclarée, mais le code de la montre", lambda e: e.code.update(
        {"CoproFirst/A.swift": e.code["CoproFirst/A.swift"].replace("let r = UserDefaults.standard\n", ""),
         "CoproFirst/B.swift": "let r = UserDefaults.standard\n"})),
    ("n'est pas déclaré par l'app", lambda e: e.montre[TYPE + "s"].append(
        {**e.montre[TYPE + "s"][0], TYPE: TYPE + "PreciseLocation"})),
    ("est absent", lambda e: setattr(e, "lire", lambda c, lire=e.lire: None if c == MANIFESTE else lire(c))),
    ("plus embarqué", lambda e: setattr(e, "projet", e.projet.replace("      - path: CoproFirstWatch\n", ""))),
]
