# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""L'écran « À propos » : ce que le PIED DE PAGE du site dit sur chaque page.

- le nom du logiciel, son site, son dépôt et sa licence (`front/src/lib/plateforme.ts`) ;
- le libellé et l'infobulle de chaque lien du pied de page — « À propos de CoproFirst »,
  « Logiciel libre », « Mentions légales », « Confidentialité » (`ELEMENTS_PIED` de
  `front/src/lib/piedDePage.ts`) —, et les clés de GET /config qui le règlent
  (`CLES_PIED` : l'année de début du « © », le texte libre) ;

→ `CoproFirst/Fonctions/APropos/Genere/TextesDuPied.swift`. Les textes légaux eux-mêmes
sont servis par l'installation (GET /config/legal), jamais écrits dans l'app.
"""

from __future__ import annotations

import re

from generateurs._commun import FONCTIONS, chaine, ecrire_table

SOURCES = ["front/src/lib/plateforme.ts", "front/src/lib/piedDePage.ts"]

#: Les liens du pied de page que l'écran reprend, par leur code (`ELEMENTS_PIED`).
LIENS = ("site", "source", "mentions", "confidentialite")


def constantes(texte: str) -> dict[str, str]:
    """`export const NOM = '…'` (ou un gabarit `…${AUTRE}…`), résolues dans l'ordre."""
    lues: dict[str, str] = {}
    for nom, simple, gabarit in re.findall(r"export const ([A-Z_]+) = (?:'([^']*)'|`([^`]*)`);", texte):
        valeur = simple or re.sub(r"\$\{([A-Z_]+)\}", lambda m: lues[m.group(1)], gabarit)
        lues[nom] = valeur
    return lues


def liens(texte: str, plateforme: dict[str, str]) -> dict[str, tuple[str, str]]:
    """`{code: (libelle, infobulle)}` des liens de `ELEMENTS_PIED`."""
    debut = texte.index("export const ELEMENTS_PIED")
    bloc = texte[debut:texte.index("];", debut)]
    resoudre = lambda s: re.sub(r"\$\{([A-Z_]+)\}", lambda m: plateforme[m.group(1)], s)  # noqa: E731
    trouves = {}
    for morceau in re.split(r"\n\t\{", bloc)[1:]:
        code = re.search(r"code: '([a-z]+)'", morceau)
        libelle = re.search(r"libelle: (?:'([^']*)'|`([^`]*)`)", morceau)
        infobulle = re.search(r"infobulle:\s*(?:'([^']*)'|`([^`]*)`)", morceau)
        if code and libelle:
            trouves[code.group(1)] = (
                resoudre(libelle.group(1) or libelle.group(2)),
                resoudre((infobulle.group(1) or infobulle.group(2)) if infobulle else ""),
            )
    absents = [c for c in LIENS if c not in trouves]
    if absents:
        raise SystemExit(f"❌ ELEMENTS_PIED : pas de lien {', '.join(absents)}")
    return trouves


def cle_pied(texte: str, nom: str) -> str:
    m = re.search(rf"\b{nom}: '([a-z_]+)'", texte[texte.index("export const CLES_PIED"):])
    if not m:
        raise SystemExit(f"❌ CLES_PIED : {nom} introuvable")
    return m.group(1)


def generer(ctx) -> str:
    plateforme = constantes(ctx.lire(SOURCES[0]))
    pied = ctx.lire(SOURCES[1])
    lus = liens(pied, plateforme)
    corps = ""
    for nom, cle in (("nomPlateforme", "NOM_PLATEFORME"), ("sitePlateforme", "SITE_PLATEFORME"),
                     ("depotSource", "DEPOT_SOURCE"), ("licenceSPDX", "LICENCE_SPDX"),
                     ("licenceNom", "LICENCE_NOM"), ("licenceURL", "LICENCE_URL")):
        if cle not in plateforme:
            raise SystemExit(f"❌ plateforme.ts : {cle} introuvable")
        corps += f"    static let {nom} = {chaine(plateforme[cle])}\n"
    corps += "    /// Les liens du pied de page : libellé, et l'infobulle du site s'il en a une.\n"
    for code in LIENS:
        libelle, infobulle = lus[code]
        corps += f"    static let {code} = (libelle: {chaine(libelle)}, aide: {chaine(infobulle)})\n"
    corps += "    /// Les clés de GET /config qui règlent la mention (`CLES_PIED`).\n"
    corps += f"    static let cleAnneeDebut = {chaine(cle_pied(pied, 'anneeDebut'))}\n"
    corps += f"    static let cleTexte = {chaine(cle_pied(pied, 'texte'))}\n"
    ecrire_table(ctx, FONCTIONS / "APropos" / "Genere" / "TextesDuPied.swift",
                 "front/src/lib/plateforme.ts, piedDePage.ts", "TextesDuPied",
                 "Ce que le pied de page du site dit sur chaque page : le logiciel, sa licence, ses liens.", corps)
    return f"{len(LIENS)} liens du pied de page"
