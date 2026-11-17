#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Le job « Dépôt » de la CI n'a qu'une étape `run`, et c'est `verifier-depot.sh` (#241).

Le poste, le hook pre-commit et la CI jouent alors exactement la même chose : le
16/11/2026, #240 est passée au poste puis a rougi en CI sur `verifier-logo.sh`, une
étape que seul le job jouait. Un contrôle de plus s'ajoute DANS `verifier-depot.sh`
(ou `scripts/controles-distants.sh`), jamais en étape du job.

Lecture au texte, sans PyYAML (absent de `python3 -I` sur le runner Linux) : le bloc
du job va de `  depot:` à la clé de job suivante, au même retrait.

Usage : python3 scripts/verifier-ci.py [--autotest]
Sortie : 0 conforme, 1 refus, 2 INCONNU (workflow ou job introuvable).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

WORKFLOW = Path(__file__).resolve().parent.parent / ".github" / "workflows" / "ci.yml"
JOB = "depot"
ATTENDU = "bash scripts/verifier-depot.sh"


def bloc_du_job(texte: str, job: str) -> list[str] | None:
    """Les lignes du job, ou None s'il n'existe pas."""
    lignes = texte.splitlines()
    try:
        debut = lignes.index(f"  {job}:")
    except ValueError:
        return None
    bloc = []
    for ligne in lignes[debut + 1:]:
        if re.match(r"^  [A-Za-z0-9_-]+:\s*$", ligne) or re.match(r"^\S", ligne):
            break
        bloc.append(ligne)
    return bloc


def refus(texte: str) -> tuple[int, list[str]]:
    """(code, messages) : 0 conforme, 1 refus, 2 INCONNU."""
    bloc = bloc_du_job(texte, JOB)
    if bloc is None:
        return 2, [f"❓ INCONNU : job « {JOB} » introuvable dans {WORKFLOW.name}"]
    runs = [l.split("run:", 1)[1].strip() for l in bloc if re.match(r"^\s+(- )?run:", l)]
    if runs == [ATTENDU]:
        return 0, [f"✅ job « {JOB} » : une seule étape, {ATTENDU}"]
    return 1, [
        f"❌ job « {JOB} » : {len(runs)} étape(s) run ({', '.join(runs) or 'aucune'}) — "
        f"une seule, « {ATTENDU} » ; un contrôle de plus s'ajoute dans ce script (#241)"
    ]


def autotest() -> int:
    conforme = (
        "jobs:\n  depot:\n    runs-on: ubuntu-latest\n    steps:\n"
        "      - uses: actions/checkout@x\n      - name: Dépôt\n"
        f"        run: {ATTENDU}\n  detection:\n    steps:\n      - run: autre\n"
    )
    deux = conforme.replace("  detection:", "      - run: bash scripts/verifier-logo.sh\n  detection:")
    autre = conforme.replace(f"run: {ATTENDU}", "run: bash scripts/autre.sh")
    bloc = conforme.replace(f"run: {ATTENDU}", f"run: |\n          {ATTENDU}")
    cas = [
        (conforme, 0, "un job conforme"),
        (deux, 1, "une deuxième étape run"),
        (autre, 1, "une étape qui n'est pas verifier-depot.sh"),
        (bloc, 1, "un bloc run: | qui pourrait enchaîner d'autres commandes"),
        (conforme.replace("  depot:", "  dépôt:"), 2, "un job introuvable"),
    ]
    ko = [nom for texte, code, nom in cas if refus(texte)[0] != code]
    for nom in ko:
        print(f"❌ autotest : {nom} mal jugé")
    return 1 if ko else 0


def main() -> int:
    if sys.argv[1:] == ["--autotest"]:
        return autotest()
    if not WORKFLOW.is_file():
        print(f"❓ INCONNU : {WORKFLOW} absent")
        return 2
    code, messages = refus(WORKFLOW.read_text(encoding="utf-8"))
    print("\n".join(messages))
    return code


if __name__ == "__main__":
    sys.exit(main())
