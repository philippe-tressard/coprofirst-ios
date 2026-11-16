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
      fichier de l'API ou une feuille de la charte hors des exceptions datées (#237), ou si
      une exception ne sert plus — et prouve d'abord, sur des modules fictifs, qu'il refuse.
"""

from __future__ import annotations

import argparse
import importlib
import pathlib
import re
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


#: Ce qu'aucun générateur ne lit dans les sources de coprofirst : l'API (`api/app/**`) et les
#: feuilles de la charte (`socle.css`, `palette-sombre.css`). Leur forme change sans prévenir et
#: la concordance devenait INCONNUE (#237) : la release publie de quoi s'en passer
#: (`constantes-clients.json`, `tables-clients.json`, `openapi.json`) — `ctx.constante`,
#: `ctx.table`. À la lecture, `Contexte.lire` refuse aussi la source d'une constante publiée.
INTERDITS = re.compile(r"^(api/app/|front/src/styles/(socle|palette-sombre)\.css$)")
#: Les lectures encore tolérées : date, raison, et ce qui les retirera. Une exception qui ne
#: couvre plus aucune source déclarée échoue — elle se retire avec la lecture.
EXCEPTIONS = {
    "api/app/utils/saisie_affaire.py":
        "16/11/2026 — MODES, SECTIONS_DE_BASE et SECTIONS_ESSENTIELLES_PAR_CATEGORIE ne sont pas "
        "publiés : coprofirst#2686 (complété le 16/11/2026)",
    "front/src/styles/socle.css":
        "16/11/2026 — palettes.py, jusqu'à palettesResolues de tables-clients.json : coprofirst-ios#227",
    "front/src/styles/palette-sombre.css":
        "16/11/2026 — palettes.py, jusqu'à palettesResolues de tables-clients.json : coprofirst-ios#227",
}


def refus_sources(modules: list, exceptions: dict[str, str] = EXCEPTIONS) -> list[str]:
    declarees = {s for m in modules for s in m.SOURCES}
    fautes = [f"❌ generateurs/{m.__name__.split('.')[-1]}.py déclare {s} : la release publie de quoi "
              "s'en passer — ctx.constante, ctx.table (#237), ou une exception datée"
              for m in modules for s in m.SOURCES if INTERDITS.match(s) and s not in exceptions]
    fautes += [f"❌ exception {s} : plus aucun générateur ne la lit — la retirer de generer.py"
               for s in sorted(set(exceptions) - declarees)]
    return fautes


def controler_sources(modules: list) -> int:
    fictif = types.SimpleNamespace(__name__="generateurs.fictif", SOURCES=["api/app/utils/mots_de_passe.py"])
    toleree = types.SimpleNamespace(__name__="generateurs.toleree", SOURCES=["front/src/styles/socle.css"])
    if (len(refus_sources([fictif], {})) != 1 or refus_sources([toleree], {"front/src/styles/socle.css": "x"})
            or len(refus_sources([fictif], {"front/src/styles/socle.css": "x"})) != 2):
        print("❌ autotest : une source interdite, une exception qui ne sert plus doivent être refusées")
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
