#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Le job « Dépôt » rejoué sur l'arbre FUSIONNÉ, à chaque poussée de `main` (#353).

`strict` reste désactivé (décision du 15/11/2026, socle `standards/09` §8 bis : la vitesse
entre les lots, la cohérence à la soumission) : une PR fusionne sur un « Dépôt » joué avant
que `main` bouge. Le 19/11/2026, #303, verte la veille, a porté `verifier-depot.sh` à 502
lignes une fois réunie à trois fusions du matin : `main` rouge neuf heures, et trois PR de
plus fusionnées dessus. Le « Dépôt » ne demande ni Xcode ni macOS (une minute sous Linux) :
`.github/workflows/depot-a-jour.yml` le rejoue, à chaque poussée de `main`, sur `main` et sur
chaque PR armée (fusion automatique, base `main`, même dépôt) réunie à `main`. Ce script est
sa décision, pure et testée :

- `main` verte, une PR dont l'arbre réuni rougit : sa fusion automatique se DÉSARME, avec un
  commentaire — sa session réunit `main`, corrige, et réarme ;
- `main` rouge ou INCONNUE : rien ne se désarme — toutes les PR réunies rougiraient, celle qui
  répare comprise ; le rouge de `main` ouvre son ticket par l'alerte commune de chaque job
  (`scripts/signaler_rouge.py`, #362) ;
- un INCONNU (réseau, outil) ou un conflit ne désarme rien (le conflit bloque déjà la fusion).

Entrée (stdin, JSON) : {"main": code, "prs": [{"numero": N, "code": c}]}, codes de
`verifier-depot.sh` (0 vert, 1 rouge, 2 INCONNU) et « conflit ». Sortie : `desarmer N` par ligne.
Usage : depot_a_jour.py decider < verdicts.json | depot_a_jour.py --autotest
"""

from __future__ import annotations

import json
import sys

def decider(verdicts: dict) -> list[str]:
    if str(verdicts.get("main")) != "0":
        return []
    return [f"desarmer {pr['numero']}" for pr in verdicts.get("prs", []) if str(pr.get("code")) == "1"]


def autotest() -> bool:
    cas = [
        ({"main": 0, "prs": []}, []),
        ({"main": 0, "prs": [{"numero": 7, "code": 1}, {"numero": 8, "code": 0}]}, ["desarmer 7"]),
        ({"main": 0, "prs": [{"numero": 7, "code": 2}, {"numero": 8, "code": "conflit"}]}, []),  # INCONNU, conflit
        ({"main": 1, "prs": [{"numero": 7, "code": 1}]}, []),        # main rouge : la réparation passe
        ({"main": 2, "prs": [{"numero": 7, "code": 1}]}, []),        # main INCONNUE : rien
        ({}, []),                                                     # rien de lu
    ]
    return all(decider(entree) == attendu for entree, attendu in cas)


def main() -> int:
    args = sys.argv[1:]
    if args == ["--autotest"]:
        ok = autotest()
        print("✅ autotest du Dépôt à jour" if ok else "❌ autotest du Dépôt à jour en échec")
        return 0 if ok else 1
    if args == ["decider"]:
        try:
            verdicts = json.load(sys.stdin)
        except json.JSONDecodeError:
            verdicts = {}
        print("\n".join(decider(verdicts)))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
