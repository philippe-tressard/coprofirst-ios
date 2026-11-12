#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Tout ce que l'app tire de coprofirst, GÉNÉRÉ — jamais recopié à la main
(garde-fou de `projets.json`) : contrat d'API, charte, palettes, pages et onglets,
tables des menus — et la copie embarquée du contenu de la vitrine, lue dans
coprofirst-site à un commit épinglé (`generateurs/vitrine.py`, #51).

Les générateurs vivent dans `scripts/generateurs/`, un module par domaine ; ce script
les DÉCOUVRE et les lance tous, dans l'ordre de leur nom, sur UNE version publiée de
coprofirst (`generateurs/_source.py`) : ses pièces jointes d'abord — le contrat
(`openapi.json`) et les tables du site (`tables-clients.json`, #128). Ajouter un domaine = ajouter un module
(`SOURCES` et `generer(ctx)`, voir `generateurs/__init__.py`) ; ce fichier ne
s'édite pas pour cela.

Usage :
  python3 scripts/generer.py
      Régénère tout depuis le PLANCHER (`generateurs/_plancher.py`) : la version sur
      laquelle l'app se génère, et ce que la CI compare.
  python3 scripts/generer.py --version v3.67.4  |  --derniere
      Depuis une autre version publiée — pour voir ce qu'une montée changerait ; le
      plancher, lui, ne monte que par `_plancher.py`.
  python3 scripts/generer.py --sources
      Les fichiers de l'archive de coprofirst encore lus, un par ligne — ce que le site
      ne publie pas en table (`generateurs/_tables.py`, `HORS_TABLES`), l'API, les licences.
"""

from __future__ import annotations

import argparse
import importlib
import pathlib
import sys
import tempfile

RACINE = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RACINE / "scripts"))

from generateurs import _plancher  # noqa: E402
from generateurs import _tables  # noqa: E402
from generateurs._commun import Contexte  # noqa: E402
from generateurs._source import SourceIllisible, Version, derniere_version  # noqa: E402


def generateurs() -> list:
    """Chaque module de `scripts/generateurs/`, hors `_*`, avec `SOURCES` et `generer`."""
    modules = []
    for fichier in sorted((RACINE / "scripts" / "generateurs").glob("[!_]*.py")):
        module = importlib.import_module(f"generateurs.{fichier.stem}")
        if not isinstance(getattr(module, "SOURCES", None), list) or not callable(getattr(module, "generer", None)):
            raise SystemExit(f"❌ generateurs/{fichier.name} : SOURCES (liste) et generer(ctx) sont requis")
        _tables.fichiers_admis(fichier.stem, module.SOURCES)
        modules.append(module)
    if not modules:
        raise SystemExit("❌ aucun générateur trouvé dans scripts/generateurs/")
    return modules


def sources(modules: list) -> list[str]:
    return sorted({s for m in modules for s in m.SOURCES})


def executer(etiquette: str, sortie: pathlib.Path) -> tuple[Contexte, list[str]]:
    """Lance chaque générateur sur la version `etiquette`, en écrivant sous `sortie`.

    Lève `SourceIllisible` si la version ne se lit pas (archive, pièce jointe) ; un
    générateur qui ne retrouve pas sa table, ou la trouve sous une autre forme, lève
    `SystemExit` (`_tables.Tables.lire`)."""
    modules = generateurs()
    version = Version(etiquette)
    with tempfile.TemporaryDirectory(prefix="coprofirst-") as dossier:
        arbre = pathlib.Path(dossier)
        commit = version.extraire(sources(modules), arbre)
        tables = _tables.Tables(etiquette, version.tables_clients())
        ctx = Contexte(racine=arbre, sortie=sortie, version=version, commit=commit, tables=tables)
        bilans = [f"{m.__name__.split('.')[-1]} : {m.generer(ctx)}" for m in modules]
    return ctx, bilans


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    choix = parser.add_mutually_exclusive_group()
    choix.add_argument("--version", default=_plancher.VERSION,
                       help=f"une version publiée de coprofirst, vX.Y.Z (défaut : le plancher, {_plancher.VERSION})")
    choix.add_argument("--derniere", action="store_true", help="la dernière release publiée")
    choix.add_argument("--sources", action="store_true", help="liste les fichiers de coprofirst lus")
    arguments = parser.parse_args()
    if arguments.sources:
        print("\n".join(sources(generateurs())))
        return
    try:
        etiquette = derniere_version() if arguments.derniere else arguments.version
        ctx, bilans = executer(etiquette, RACINE)
    except SourceIllisible as erreur:
        raise SystemExit(f"❓ INCONNU : {erreur}") from erreur
    print(f"✅ {ctx.provenance}\n   " + "\n   ".join(bilans))


if __name__ == "__main__":
    main()
