# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""L'écran « À propos » : ce que le PIED DE PAGE du site dit sur chaque page.

- le nom du logiciel, son site, son dépôt et sa licence (table `plateforme`) ;
- le libellé et l'infobulle de chaque lien du pied de page — « À propos de CoproFirst »,
  « Logiciel libre », « Mentions légales », « Confidentialité » (table `elementsPied`) —,
  et les clés de GET /config qui le règlent (table `clesPied` : l'année de début du
  « © », le texte libre) ;

→ `CoproFirst/Fonctions/APropos/Genere/TextesDuPied.swift`. Les textes légaux eux-mêmes
sont servis par l'installation (GET /config/legal), jamais écrits dans l'app.
"""

from __future__ import annotations

from generateurs._commun import FONCTIONS, chaine, ecrire_table
from generateurs._tables import Facultatif, source

SOURCES: list[str] = []

#: Les liens du pied de page que l'écran reprend, par leur code (`elementsPied`).
LIENS = ("site", "source", "mentions", "confidentialite")
#: Le nom Swift de chaque constante de la plateforme, et sa clé dans la table `plateforme`.
PLATEFORME = (("nomPlateforme", "nom"), ("sitePlateforme", "site"), ("depotSource", "depotSource"),
              ("licenceSPDX", "licenceSpdx"), ("licenceNom", "licenceNom"), ("licenceURL", "licenceUrl"))


def liens(ctx) -> dict[str, tuple[str, str]]:
    """`{code: (libelle, infobulle)}` des liens de `elementsPied` ; un lien sans infobulle
    sur le site n'en a pas dans l'app."""
    elements = ctx.table("elementsPied", [{"code": str, "libelle": str,
                                           "lien": Facultatif({"infobulle": Facultatif(str)})}])
    trouves = {e["code"]: (e["libelle"], e["lien"].get("infobulle", "")) for e in elements if "lien" in e}
    absents = [c for c in LIENS if c not in trouves]
    if absents:
        raise SystemExit(f"❌ elementsPied : pas de lien {', '.join(absents)}")
    return trouves


def generer(ctx) -> str:
    plateforme = ctx.table("plateforme", {cle: str for _, cle in PLATEFORME})
    cles = ctx.table("clesPied", {"anneeDebut": str, "texte": str})
    lus = liens(ctx)
    corps = "".join(f"    static let {nom} = {chaine(plateforme[cle])}\n" for nom, cle in PLATEFORME)
    corps += "    /// Les liens du pied de page : libellé, et l'infobulle du site s'il en a une.\n"
    for code in LIENS:
        libelle, infobulle = lus[code]
        corps += f"    static let {code} = (libelle: {chaine(libelle)}, aide: {chaine(infobulle)})\n"
    corps += "    /// Les clés de GET /config qui règlent la mention (`CLES_PIED`).\n"
    corps += f"    static let cleAnneeDebut = {chaine(cles['anneeDebut'])}\n"
    corps += f"    static let cleTexte = {chaine(cles['texte'])}\n"
    ecrire_table(ctx, FONCTIONS / "APropos" / "Genere" / "TextesDuPied.swift",
                 source("plateforme", "elementsPied", "clesPied"), "TextesDuPied",
                 "Ce que le pied de page du site dit sur chaque page : le logiciel, sa licence, ses liens.", corps)
    return f"{len(LIENS)} liens du pied de page"
