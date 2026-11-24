#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Une version est-elle au moins le minimum ? Comparée nombre par nombre (26.10 > 26.6) (#369).

Usage : version_au_moins.py MINIMUM VERSION — sortie 0 oui, 1 non, 2 INCONNU (illisible).
Lancé par scripts/generer-projet.sh pour `XCODE_MINIMUM` (outillage.env). `--autotest`.
"""

from __future__ import annotations

import sys


def comparer(minimum: str, version: str) -> int:
    try:
        lus = [tuple(int(n) for n in v.strip().split(".")) for v in (minimum, version)]
    except ValueError:
        return 2
    return 0 if lus[1] >= lus[0] else 1


def autotest() -> bool:
    cas = {("26.6", "26.6"): 0, ("26.6", "26.5"): 1, ("26.6", "27.2"): 0, ("26.6", "26.10"): 0,
           ("26.6", "x"): 2, ("26.6", ""): 2, ("26", "26.0.1"): 0}
    return all(comparer(*entree) == attendu for entree, attendu in cas.items())


if __name__ == "__main__":
    if sys.argv[1:] == ["--autotest"]:
        ok = autotest()
        print("✅ autotest de la comparaison des versions" if ok else "❌ autotest des versions en échec")
        sys.exit(0 if ok else 1)
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    sys.exit(comparer(sys.argv[1], sys.argv[2]))
