#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Tout ce que l'app tire de coprofirst, GÉNÉRÉ — jamais recopié à la main
(garde-fou de `projets.json`) : contrat d'API, charte, palettes, pages et onglets,
tables des menus — et la copie embarquée du contenu de la vitrine, lue dans
coprofirst-site à un commit épinglé (`generateurs/vitrine.py`, #51).

Les générateurs vivent dans `scripts/generateurs/`, un module par domaine ; ce script
les DÉCOUVRE et les lance tous, dans l'ordre de leur nom, sur UNE version publiée de
coprofirst (`generateurs/_source.py`). Ajouter un domaine = ajouter un module
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
      Les fichiers de coprofirst lus, un par ligne ; échoue si un générateur déclare un
      fichier dont les constantes sont PUBLIÉES à la release (#237) — et prouve d'abord,
      sur un module fictif, qu'il refuse.
"""

from __future__ import annotations

import argparse
import importlib
import pathlib
import sys
import tempfile
import types

RACINE = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RACINE / "scripts"))

from generateurs import _plancher  # noqa: E402
from generateurs._commun import Contexte  # noqa: E402
from generateurs._source import SourceIllisible, Version, derniere_version  # noqa: E402


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


def sources(modules: list) -> list[str]:
    return sorted({s for m in modules for s in m.SOURCES})


#: Les fichiers du serveur dont coprofirst PUBLIE les constantes (`constantes-clients.json`,
#: joint à chaque release depuis v3.102.0) : ils ne se lisent plus par motif — leur forme
#: change sans prévenir, et la concordance devenait INCONNUE (#237). `ctx.constante`.
#: À la lecture, `Contexte.lire` refuse aussi tout fichier source d'une constante publiée.
PUBLIES = frozenset({
    "api/app/utils/avis.py", "api/app/utils/html_sur.py",
    "api/app/utils/mots_de_passe.py", "api/app/utils/preferences_mail.py",
})


def refus_sources(modules: list) -> list[str]:
    return [f"❌ generateurs/{m.__name__.split('.')[-1]}.py déclare {s} : ses constantes sont publiées "
            "(constantes-clients.json) — ctx.constante (#237)"
            for m in modules for s in m.SOURCES if s in PUBLIES]


def controler_sources(modules: list) -> int:
    fictif = types.SimpleNamespace(__name__="generateurs.fictif", SOURCES=["api/app/utils/mots_de_passe.py"])
    if len(refus_sources([fictif])) != 1:
        print("❌ autotest : un module qui déclare une source publiée doit être refusé")
        return 1
    fautes = refus_sources(modules)
    print("\n".join(fautes or sources(modules)))
    return 1 if fautes else 0


def executer(etiquette: str, sortie: pathlib.Path) -> tuple[Contexte, list[str]]:
    """Lance chaque générateur sur la version `etiquette`, en écrivant sous `sortie`.

    Lève `SourceIllisible` si la version ne se lit pas ; un générateur qui ne retrouve
    pas sa table lève `SystemExit` (la source a changé de forme)."""
    modules = generateurs()
    version = Version(etiquette)
    with tempfile.TemporaryDirectory(prefix="coprofirst-") as dossier:
        arbre = pathlib.Path(dossier)
        commit = version.extraire(sources(modules), arbre)
        ctx = Contexte(racine=arbre, sortie=sortie, version=version, commit=commit)
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
        raise SystemExit(controler_sources(generateurs()))
    try:
        etiquette = derniere_version() if arguments.derniere else arguments.version
        ctx, bilans = executer(etiquette, RACINE)
    except SourceIllisible as erreur:
        raise SystemExit(f"❓ INCONNU : {erreur}") from erreur
    print(f"✅ {ctx.provenance}\n   " + "\n   ".join(bilans))


if __name__ == "__main__":
    main()
