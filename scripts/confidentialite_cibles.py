# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Le manifeste de confidentialité PROPRE d'une cible — l'Apple TV (#218, lot 5), l'Apple
Watch (#226) —, jugé par `verifier-confidentialite.py`, qui le charge comme il charge
`verifier-simule.py`.

Une cible a son paquet, donc son manifeste. La fiche, elle, est celle de l'app : App Store
Connect ne connaît qu'une fiche par app, iPhone, montre et TV ensemble. Ce module refuse
qu'une cible :

  - trace, ou déclare un type mal formé (les règles de l'app, `juger_manifeste`) ;
  - appelle une API « à raison requise » — dans SON code, celui que compile sa cible
    (`project.yml`, partages nommés compris, et le paquet ClientAPI qu'elle embarque), dans
    les paquets embarqués ou le client généré — sans la déclarer, ou en déclare une qu'elle
    n'appelle plus (`juger_api`) ;
  - fasse un envoi classé, ou porte un symbole, qui trahit un type qu'elle ne déclare pas ;
  - déclare un type de donnée que le manifeste de l'app, donc la fiche, ne déclare pas ;
  - ne porte pas son manifeste (absent, ou hors des sources de la cible).
"""

from __future__ import annotations

import re

MANIFESTES = {
    "CoproFirstTV": "CoproFirstTV/PrivacyInfo.xcprivacy",
    "CoproFirstWatch": "CoproFirstWatch/PrivacyInfo.xcprivacy",
}
CLIENT = "Paquets/ClientAPI/Sources/"  # le paquet ClientAPI, embarqué par chaque cible


def sources(projet: str, cible: str) -> list[str]:
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


def code_de_la_cible(code: dict[str, str], projet: str, cible: str) -> dict[str, str]:
    """Le code que compile la cible : un dossier source, un fichier nommé, et ClientAPI."""
    racines = sources(projet, cible)
    return {c: t for c, t in code.items() if c.startswith(CLIENT) or any(
        c == r or c.startswith(r.rstrip("/") + "/") for r in racines)}


def juger(etat, v, types_app: set[str], classes: dict[str, set[str]]) -> list[str]:
    """`v` : le juge (`verifier-confidentialite.py`), dont les règles servent ici, jamais copiées."""
    fautes = []
    for cible, chemin in MANIFESTES.items():
        manifeste = etat.cibles.get(cible)
        if manifeste is None:
            fautes.append(f"{chemin} est absent : la cible {cible} a son paquet, donc son manifeste")
            continue
        if cible not in sources(etat.projet, cible):
            fautes.append(f"{chemin} n'est plus dans une source de la cible {cible} : il n'est plus embarqué")
        code, types = code_de_la_cible(etat.code, etat.projet, cible), v.types_de(manifeste)
        fautes += [f.replace("manifeste :", f"manifeste de {cible} :", 1) for f in v.juger_manifeste(manifeste)]
        fautes += v.juger_api(manifeste, code, f"le code de {cible}", sans_objet=True)
        for identite, lues in sorted(etat.paquets.items()):
            fautes += v.juger_api(manifeste, lues, f"le paquet {identite}, embarqué dans {cible}")
        if etat.genere is not None:
            fautes += v.juger_api(manifeste, etat.genere, f"le client généré, embarqué dans {cible}")
        fautes += v.envois_et_indices(classes, code, types, f"le manifeste de {cible}")
        fautes += [
            f"manifeste de {cible} : {v.TYPE}{t} n'est pas déclaré par l'app — la fiche (une par app) ne le dit pas"
            for t in sorted(types - types_app)]
    return fautes
