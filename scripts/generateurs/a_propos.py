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

Les trois tables se lisent dans `tables-clients.json` de la release (`ctx.table`, #356) :
`plateforme`, `elementsPied`, `clesPied` — plus aucun fichier du site ne se lit ici.
"""

from __future__ import annotations

from generateurs._commun import FONCTIONS, chaine, ecrire_table

SOURCES: list[str] = []  # tables-clients.json de la release (#356), pas les sources du site

#: Les liens du pied de page que l'écran reprend, par leur code (`ELEMENTS_PIED`).
LIENS = ("site", "source", "mentions", "confidentialite")
#: Le nom Swift de chaque champ de `plateforme` (`NOM_PLATEFORME`… de `plateforme.ts`).
PLATEFORME = (("nomPlateforme", "nom"), ("sitePlateforme", "site"), ("depotSource", "depotSource"),
              ("licenceSPDX", "licenceSpdx"), ("licenceNom", "licenceNom"), ("licenceURL", "licenceUrl"))


def _texte(nom: str, valeur) -> str:
    if not isinstance(valeur, str):
        raise SystemExit(f"❌ {nom} : forme inattendue ({valeur!r}) — l'app doit l'apprendre")
    return valeur


def liens(ctx) -> dict[str, tuple[str, str]]:
    """`{code: (libelle, infobulle)}` des liens de `elementsPied` (libellés déjà résolus)."""
    elements = ctx.table("elementsPied")
    if not (isinstance(elements, list) and all(isinstance(e, dict) for e in elements)):
        raise SystemExit(f"❌ elementsPied : forme inattendue ({elements!r}) — l'app doit l'apprendre")
    trouves = {}
    for e in elements:
        if e.get("code") in LIENS:
            lien = e.get("lien") if isinstance(e.get("lien"), dict) else {}
            trouves[e["code"]] = (_texte(f"elementsPied.{e['code']}.libelle", e.get("libelle")),
                                  _texte(f"elementsPied.{e['code']}.infobulle", lien.get("infobulle", "")))
    absents = [c for c in LIENS if c not in trouves]
    if absents:
        raise SystemExit(f"❌ elementsPied : pas de lien {', '.join(absents)}")
    return trouves


def _dictionnaire(ctx, nom: str) -> dict:
    valeur = ctx.table(nom)
    if not isinstance(valeur, dict):
        raise SystemExit(f"❌ {nom} : forme inattendue ({valeur!r}) — l'app doit l'apprendre")
    return valeur


def generer(ctx) -> str:
    plateforme = _dictionnaire(ctx, "plateforme")
    cles = _dictionnaire(ctx, "clesPied")
    lus = liens(ctx)
    corps = ""
    for nom, cle in PLATEFORME:
        if not plateforme.get(cle):
            raise SystemExit(f"❌ plateforme : {cle} introuvable")
        corps += f"    static let {nom} = {chaine(_texte(f'plateforme.{cle}', plateforme[cle]))}\n"
    corps += "    /// Les liens du pied de page : libellé, et l'infobulle du site s'il en a une.\n"
    for code in LIENS:
        libelle, infobulle = lus[code]
        corps += f"    static let {code} = (libelle: {chaine(libelle)}, aide: {chaine(infobulle)})\n"
    corps += "    /// Les clés de GET /config qui règlent la mention (`CLES_PIED`).\n"
    for nom, cle in (("cleAnneeDebut", "anneeDebut"), ("cleTexte", "texte")):
        if not cles.get(cle):
            raise SystemExit(f"❌ clesPied : {cle} introuvable")
        corps += f"    static let {nom} = {chaine(_texte(f'clesPied.{cle}', cles[cle]))}\n"
    # L'en-tête « Source : » reste celui des fichiers d'où le serveur tire ces tables : la
    # concordance le compare au-delà de la version (#356).
    ecrire_table(ctx, FONCTIONS / "APropos" / "Genere" / "TextesDuPied.swift",
                 "front/src/lib/plateforme.ts, piedDePage.ts", "TextesDuPied",
                 "Ce que le pied de page du site dit sur chaque page : le logiciel, sa licence, ses liens.", corps)
    return f"{len(LIENS)} liens du pied de page"
