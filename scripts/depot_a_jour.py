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

- une PR dont l'arbre réuni rougit : sa fusion automatique se DÉSARME, avec un commentaire —
  sa session réunit `main`, corrige, et réarme ; un INCONNU (réseau, outil) ou un conflit ne
  désarme rien (le conflit bloque déjà la fusion) ;
- `main` rouge : un ticket « sante-main » s'ouvre aussitôt, ou se complète ; `main` verte :
  il se ferme ; INCONNU : rien ne se ferme.

Entrée (stdin, JSON) : {"main": code, "ticket": "N" ou "", "prs": [{"numero": N, "code": c}]},
codes de `verifier-depot.sh` (0 vert, 1 rouge, 2 INCONNU) et « conflit ». Sortie : une action
par ligne — `desarmer N`, `ticket ouvrir|completer|fermer|rien`.
Usage : depot_a_jour.py decider < verdicts.json | depot_a_jour.py titre | depot_a_jour.py --autotest
"""

from __future__ import annotations

import json
import sys

TITRE = "main : le job « Dépôt » est rouge"


def decider(verdicts: dict) -> list[str]:
    actions = [f"desarmer {pr['numero']}" for pr in verdicts.get("prs", []) if str(pr.get("code")) == "1"]
    code, ouvert = str(verdicts.get("main")), bool(verdicts.get("ticket"))
    if code == "1":
        actions.append("ticket completer" if ouvert else "ticket ouvrir")
    elif code == "0" and ouvert:
        actions.append("ticket fermer")
    else:
        actions.append("ticket rien")
    return actions


def autotest() -> bool:
    cas = [
        ({"main": 0, "ticket": "", "prs": []}, ["ticket rien"]),
        ({"main": 0, "ticket": "", "prs": [{"numero": 7, "code": 1}, {"numero": 8, "code": 0}]},
         ["desarmer 7", "ticket rien"]),
        ({"main": 0, "ticket": "", "prs": [{"numero": 7, "code": 2}, {"numero": 8, "code": "conflit"}]},
         ["ticket rien"]),                                    # INCONNU, conflit : rien ne se désarme
        ({"main": 1, "ticket": "", "prs": []}, ["ticket ouvrir"]),
        ({"main": 1, "ticket": "12", "prs": []}, ["ticket completer"]),
        ({"main": 0, "ticket": "12", "prs": []}, ["ticket fermer"]),
        ({"main": 2, "ticket": "12", "prs": []}, ["ticket rien"]),   # INCONNU ne ferme rien
        ({"ticket": "12"}, ["ticket rien"]),                          # rien de lu
    ]
    return all(decider(entree) == attendu for entree, attendu in cas)


def main() -> int:
    args = sys.argv[1:]
    if args == ["--autotest"]:
        ok = autotest()
        print("✅ autotest du Dépôt à jour" if ok else "❌ autotest du Dépôt à jour en échec")
        return 0 if ok else 1
    if args == ["titre"]:
        print(TITRE)
        return 0
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
