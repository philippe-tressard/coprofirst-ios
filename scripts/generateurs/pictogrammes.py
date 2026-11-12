# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les PICTOGRAMMES de la gouttière du fil, au trait, tels que le site les dessine.

Le site dessine ses pictogrammes depuis un catalogue de tracés Lucide
(`front/src/lib/icones-svg.json`, rendu par `Icon.svelte` : grille de 24, trait de
1,5, bouts ronds). L'app les traduisait en SF Symbols pleins — une autre famille, un
autre dessin (demande du 11/11/2026 : « les icônes du web sont à reprendre pour
cette gouttière »).

Ce module en extrait ceux que la gouttière d'une carte du fil peut montrer : le
pictogramme de chaque rubrique (`naturesDuFil`) et celui de chaque nature d'affaire
(`naturesAffaire`, `classeDuFlux` du site), tables de `tables-clients.json` (#128), avec
les attributs du trait (`attributsTrace`). Chacun
devient une image vectorielle du catalogue `Pictogrammes.xcassets`, dans l'espace de
noms `Lucide` (`Image("Lucide/wrench")`), rendue en modèle : la carte la teinte.

Les tracés sont de Lucide (ISC ; MIT pour la part issue de Feather) : leurs deux textes de
licence, avec leurs titulaires, sont recopiés de coprofirst dans `LICENSES/` (REUSE) et
dans `LicencesDesPictogrammes.swift`, que l'écran « À propos » affiche — l'ISC exige que
l'avis accompagne chaque copie.
"""

from __future__ import annotations

import json
import pathlib
import re

from generateurs import charte
from generateurs._commun import SIGNATURE

# Le catalogue des tracés et les licences ne sont pas des tables : ils se lisent dans
# l'archive. Le reste vient de `tables-clients.json` (#128).
SOURCES = [
    "front/src/lib/icones-svg.json",
    "LICENSES/ISC.txt",
    "LICENSES/MIT.txt",
]

CATALOGUE = pathlib.Path("CoproFirst/Ressources/Pictogrammes.xcassets")
ESPACE = "Lucide"
#: Les attributs du <svg> (`attributsTrace`), lus et non recopiés : le trait suit le site.
ATTRIBUTS = ("viewBox", "fill", "stroke-width", "stroke-linecap", "stroke-linejoin")


def _json(objet: dict) -> str:
    """Le JSON d'un catalogue, à la forme qu'Xcode écrit (deux espaces, « : »)."""
    return json.dumps(objet, ensure_ascii=False, indent=2).replace('": ', '" : ') + "\n"


def attributs_du_site(ctx) -> str:
    """`viewBox="0 0 24 24" fill="none" stroke-width="1.5" …`, tels qu'`Icon.svelte` les pose
    (`attributsTrace`, publiée depuis `ATTRIBUTS_TRACE` d'`icones.ts`)."""
    publies = ctx.table("attributsTrace")
    lus = []
    for nom in ATTRIBUTS:
        valeur = publies.get(nom)
        if not isinstance(valeur, str) or not re.fullmatch(r'[^"<>&{}]+', valeur):
            raise SystemExit(f"❌ attributsTrace : l'attribut {nom} du <svg> est absent ou illisible ({valeur!r})")
        lus.append(f'{nom}="{valeur}"')
    return " ".join(lus)


def noms(ctx) -> list[str]:
    """Les pictogrammes que la gouttière du fil peut montrer, triés."""
    rubriques = {icone for *_, icone in charte.natures_du_fil(ctx)}
    natures = {n["icone"] for n in ctx.table("naturesAffaire")}
    return sorted(rubriques | natures)


def generer(ctx) -> str:
    catalogue = json.loads(ctx.lire(SOURCES[0]))
    attributs = attributs_du_site(ctx)
    retenus = noms(ctx)
    absents = [nom for nom in retenus if nom not in catalogue]
    if absents:
        raise SystemExit(f"❌ icones-svg.json : pas de tracé pour {', '.join(absents)}")
    info = {"info": {"author": "xcode", "version": 1}}
    ctx.ecrire(CATALOGUE / "Contents.json", _json(info))
    ctx.ecrire(CATALOGUE / f"{ESPACE}" / "Contents.json",
               _json({**info, "properties": {"provides-namespace": True}}))
    for nom in retenus:
        dossier = CATALOGUE / ESPACE / f"{nom}.imageset"
        # Le trait en noir : rendue en modèle, l'image ne garde que sa forme, la teinte
        # vient de la carte (`currentColor` du site).
        svg = (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            f"<!-- {SIGNATURE} -->\n"
            f"<!-- Source : {ctx.provenance}, {SOURCES[0]} ({nom}). -->\n"
            f'<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" {attributs} '
            f'stroke="#000000">{catalogue[nom]}</svg>\n'
        )
        ctx.ecrire(dossier / f"{nom}.svg", svg)
        ctx.ecrire(dossier / "Contents.json", _json({
            "images": [{"filename": f"{nom}.svg", "idiom": "universal"}],
            **info,
            "properties": {"preserves-vector-representation": True, "template-rendering-intent": "template"},
        }))
    licences(ctx)
    return f"{len(retenus)} pictogrammes Lucide de la gouttière du fil"


def licences(ctx) -> None:
    """Les licences des tracés, telles que coprofirst les déclare — pour REUSE et pour l'app."""
    textes = {spdx: ctx.lire(f"LICENSES/{spdx}.txt") for spdx in ("ISC", "MIT")}
    corps = ctx.entete("LICENSES/ISC.txt et MIT.txt")
    corps += "\n/// Les licences des pictogrammes Lucide de l'app (`Pictogrammes.xcassets`), avec\n"
    corps += "/// leurs titulaires : l'avis doit accompagner chaque copie (ISC, MIT).\n"
    corps += "enum LicencesDesPictogrammes {\n"
    corps += "    static let composant = \"Lucide\"\n"
    for spdx, texte in textes.items():
        ctx.ecrire(pathlib.Path("LICENSES") / f"{spdx}.txt", texte)
        corps += f'    static let {spdx.lower()} = #"""\n'
        corps += "".join(f"        {ligne}".rstrip() + "\n" for ligne in texte.rstrip("\n").splitlines())
        corps += '        """#\n'
    corps += "}\n"
    ctx.ecrire(pathlib.Path("CoproFirst/Charte/LicencesDesPictogrammes.swift"), corps)
