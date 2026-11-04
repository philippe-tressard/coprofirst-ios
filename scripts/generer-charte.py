#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que l'app tire des sources de coprofirst, GÉNÉRÉ — jamais recopié à la main
(garde-fou de `projets.json`).

Les générateurs vivent dans `scripts/generateurs/`, un module par domaine (palettes,
charte, onglets…) ; ce script les DÉCOUVRE et les lance tous, dans l'ordre de leur
nom. Ajouter un domaine = ajouter un module (`SOURCES` et `generer(ctx)`, voir
`generateurs/__init__.py`) ; ce fichier ne s'édite pas pour cela.

Usage :
  python3 scripts/generer-charte.py [chemin/vers/coprofirst/front]
      Sans argument : $COPROFIRST_RACINE/front — le clone de coprofirst du poste
      (défaut : /Volumes/Data/Dev/5hostachy).
  python3 scripts/generer-charte.py --sources
      La liste des fichiers de coprofirst lus, un par ligne (concordance, #20).
"""

from __future__ import annotations

import importlib
import os
import pathlib
import subprocess
import sys

RACINE = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RACINE / "scripts"))

from generateurs._commun import Contexte  # noqa: E402


def generateurs() -> list:
    """Chaque module de `scripts/generateurs/`, hors `_*`, avec `SOURCES` et `generer`."""
    modules = []
    for fichier in sorted((RACINE / "scripts" / "generateurs").glob("[!_]*.py")):
        module = importlib.import_module(f"generateurs.{fichier.stem}")
        if not isinstance(getattr(module, "SOURCES", None), list) or not callable(getattr(module, "generer", None)):
            raise SystemExit(f"❌ generateurs/{fichier.name} : SOURCES (liste) et generer(ctx) sont requis")
        modules.append(module)
    if not modules:
        raise SystemExit("❌ aucun générateur trouvé dans scripts/generateurs/")
    return modules


def main() -> None:
    modules = generateurs()
    if "--sources" in sys.argv:
        print("\n".join(sorted({s for m in modules for s in m.SOURCES})))
        return
    racine_coprofirst = os.environ.get("COPROFIRST_RACINE", "/Volumes/Data/Dev/5hostachy")
    front = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else f"{racine_coprofirst}/front")
    commit = subprocess.run(["git", "-C", str(front), "rev-parse", "--short=9", "HEAD"],
                            capture_output=True, text=True, check=True).stdout.strip()
    ctx = Contexte(front=front, sortie=RACINE, commit=commit)
    bilans = [f"{m.__name__.split('.')[-1]} : {m.generer(ctx)}" for m in modules]
    print(f"✅ coprofirst@{commit}\n   " + "\n   ".join(bilans))


if __name__ == "__main__":
    main()
