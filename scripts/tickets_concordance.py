#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les TICKETS de la concordance quotidienne (#20, #67) : une décision pure, jouée par
`.github/workflows/concordance.yml`, qui n'exécute que ce qu'elle dit.

Entrées : les codes de sortie de `scripts/concordance.py` (`--plancher`, `--montee` :
0 rien, 1 écart, 2 INCONNU, 3 montée possible ; une chaîne vide si le pas n'a rien
écrit) et les tickets ouverts sous chaque étiquette.

- VERT (plancher 0, montée 0 ou 3) : le ticket « concordance » ouvert est FERMÉ, avec
  le run en commentaire — un incident passager ne laisse plus de faux ticket (#65) ;
- ROUGE (plancher 1) ou INCONNU (tout le reste, codes vides compris) : le ticket est
  ouvert, ou complété s'il l'est déjà. Rien ne se ferme sur un rouge ni sur un INCONNU :
  ce qui n'a pas pu être comparé n'est pas un vert (standards/04) ;
- « a-monter » (montée 3) garde sa logique propre : ouvert une fois, puis mis à jour,
  jamais rouge, jamais fermé ici — il se ferme quand on monte le plancher.

Le ticket d'une étiquette se reconnaît à son étiquette ET à son TITRE (`TITRES`, le seul
endroit où ils s'écrivent) : le 11/11/2026, un ticket fonctionnel étiqueté « a-monter »
par erreur (#93) a été pris pour celui de la concordance, et son corps réécrit.

Usage : python3 scripts/tickets_concordance.py --autotest
        python3 scripts/tickets_concordance.py decider PLANCHER MONTEE N_CONCORDANCE N_A_MONTER
        (un numéro vide : aucun ticket ouvert ; sortie `cle=valeur`, pour $GITHUB_OUTPUT)
        gh issue list --label E --state open --json number,title | … choisir E
        (le numéro du ticket de la concordance sous l'étiquette E, ou rien)
        python3 scripts/tickets_concordance.py titre E   (le titre du ticket à ouvrir)
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass

VERT, ROUGE, INCONNU = "vert", "rouge", "inconnu"
OUVRIR, COMPLETER, FERMER, METTRE_A_JOUR, RIEN = "ouvrir", "completer", "fermer", "mettre-a-jour", "rien"

#: étiquette → le titre du ticket que la concordance ouvre, et auquel elle le reconnaît.
TITRES = {
    "concordance": "Concordance avec CoproFirst : écart au plancher ou version illisible",
    "a-monter": "CoproFirst : une version publiée au-dessus du plancher de l'app",
}


@dataclass(frozen=True)
class Decision:
    verdict: str
    concordance: str  # ouvrir | completer | fermer | rien
    a_monter: str  # ouvrir | mettre-a-jour | rien


def verdict(plancher: str, montee: str) -> str:
    """Un vert se prouve : seuls 0/0 et 0/3 en sont un ; un code inattendu est INCONNU."""
    if plancher == "1":
        return ROUGE
    if plancher == "0" and montee in ("0", "3"):
        return VERT
    return INCONNU


def decider(plancher: str, montee: str, concordance_ouvert: bool, a_monter_ouvert: bool) -> Decision:
    juge = verdict(plancher, montee)
    if juge == VERT:
        concordance = FERMER if concordance_ouvert else RIEN
    else:
        concordance = COMPLETER if concordance_ouvert else OUVRIR
    a_monter = (METTRE_A_JOUR if a_monter_ouvert else OUVRIR) if montee == "3" else RIEN
    return Decision(juge, concordance, a_monter)


def choisir(etiquette: str, tickets: list[dict]) -> str:
    """Le numéro du ticket de la concordance parmi les tickets ouverts sous `etiquette`
    (`gh issue list --json number,title`) : celui qui porte SON titre, jamais un ticket
    qu'on a seulement étiqueté. Aucun : chaîne vide — la concordance ouvrira le sien."""
    titre = TITRES[etiquette]
    return next((str(t["number"]) for t in tickets if t.get("title") == titre), "")


def rejouer(runs: list[tuple[str, str]]) -> list[tuple[str, bool, bool]]:
    """Joue une suite de runs sur des tickets simulés : (action, concordance ouvert,
    a-monter ouvert) après chaque run — un passage se teste comme un passage."""
    concordance, a_monter, etats = False, False, []
    for plancher, montee in runs:
        d = decider(plancher, montee, concordance, a_monter)
        concordance = {OUVRIR: True, FERMER: False}.get(d.concordance, concordance)
        a_monter = a_monter or d.a_monter == OUVRIR
        etats.append((d.concordance, concordance, a_monter))
    return etats


def autotest() -> int:
    passages = [
        ("rouge → vert : ouvert, puis fermé", [("1", "0"), ("0", "0")],
         [(OUVRIR, True, False), (FERMER, False, False)]),
        ("INCONNU → vert : ouvert, puis fermé (#65)", [("2", "0"), ("0", "0")],
         [(OUVRIR, True, False), (FERMER, False, False)]),
        ("vert → vert : rien n'est ouvert ni fermé", [("0", "0"), ("0", "0")],
         [(RIEN, False, False), (RIEN, False, False)]),
        ("rouge → INCONNU → rouge : complété, jamais fermé", [("1", "0"), ("2", "0"), ("1", "2")],
         [(OUVRIR, True, False), (COMPLETER, True, False), (COMPLETER, True, False)]),
        ("une montée seule n'est pas un rouge : a-monter ouvert une fois",
         [("0", "3"), ("0", "3")], [(RIEN, False, True), (RIEN, False, True)]),
        ("INCONNU de la montée → vert avec montée : fermé, a-monter ouvert",
         [("0", "2"), ("0", "3")], [(OUVRIR, True, False), (FERMER, False, True)]),
        ("un pas qui n'a rien écrit est INCONNU, jamais vert", [("1", "0"), ("", "0"), ("0", "")],
         [(OUVRIR, True, False), (COMPLETER, True, False), (COMPLETER, True, False)]),
    ]
    rate = 0
    for nom, runs, attendu in passages:
        obtenu = rejouer(runs)
        if obtenu != attendu:
            print(f"❌ {nom} : {obtenu}")
            rate += 1
    if decider("0", "3", False, True).a_monter != METTRE_A_JOUR:
        print("❌ a-monter déjà ouvert : mis à jour, pas rouvert")
        rate += 1
    # Le ticket se choisit au titre (#93) : un ticket étranger sous l'étiquette n'est pas
    # celui de la concordance, même listé le premier ; seul, il laisse la place vide.
    etranger = {"number": 93, "title": "Historique : lire peut_modifier / peut_supprimer d'une entrée"}
    le_sien = {"number": 60, "title": TITRES["a-monter"]}
    choix = [
        ("un ticket étranger étiqueté a-monter n'est pas choisi", choisir("a-monter", [etranger, le_sien]), "60"),
        ("seul sous l'étiquette, le ticket étranger laisse la place vide", choisir("a-monter", [etranger]), ""),
        ("aucun ticket ouvert : rien", choisir("concordance", []), ""),
        ("le titre d'une étiquette ne vaut pas pour l'autre", choisir("concordance", [le_sien]), ""),
    ]
    for nom, obtenu, attendu in choix:
        if obtenu != attendu:
            print(f"❌ {nom} : « {obtenu} »")
            rate += 1
    print("✅ tickets_concordance : autotest" if rate == 0 else f"── {rate} cas en échec")
    return 0 if rate == 0 else 1


def _ouvert(numero: str) -> bool:
    if numero and not numero.isdigit():
        raise ValueError(f"numéro de ticket illisible : {numero!r}")
    return bool(numero)


def main(argv: list[str]) -> int:
    if argv[1:] == ["--autotest"]:
        return autotest()
    if len(argv) == 6 and argv[1] == "decider":
        try:
            d = decider(argv[2], argv[3], _ouvert(argv[4]), _ouvert(argv[5]))
        except ValueError as erreur:
            print(f"INCONNU : {erreur}", file=sys.stderr)
            return 2
        print(f"verdict={d.verdict}\nconcordance={d.concordance}\na_monter={d.a_monter}")
        return 0
    if len(argv) == 3 and argv[1] in ("choisir", "titre") and argv[2] in TITRES:
        if argv[1] == "titre":
            print(TITRES[argv[2]])
            return 0
        try:
            print(choisir(argv[2], json.load(sys.stdin)))
        except (ValueError, TypeError, KeyError, AttributeError) as erreur:
            print(f"INCONNU : liste des tickets illisible ({erreur})", file=sys.stderr)
            return 2
        return 0
    print("usage : tickets_concordance.py --autotest | decider PLANCHER MONTEE N_CONCORDANCE N_A_MONTER"
          " | choisir ETIQUETTE < tickets.json | titre ETIQUETTE", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
