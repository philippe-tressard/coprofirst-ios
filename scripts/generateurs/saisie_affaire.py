# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""La saisie d'une affaire, Essentielle ou Complète (#69, coprofirst#2595).

Ce qui DÉCIDE vient du serveur, à l'exécution : le mode du compte
(`UserRead.saisie_affaire_effective`) et les sections de chaque catégorie
(`CategorieServie.sections_essentielles`, `GET /tickets/referentiels`). Ce module ne
génère que ce que le contrat ne sert pas, et ce que l'API SIMULÉE doit servir :

- les choix du Profil : `OPTIONS_SAISIE` (`front/src/lib/saisie-affaire.ts`) restreintes
  aux modes que le SERVEUR enregistre (`modesSaisie`, `MODES` du serveur) —
  « Selon mon rôle » n'en est pas un (coprofirst#2615 le retire), l'app ne l'offre pas ;
- le libellé de chaque mode (`LIBELLE_MODE`) ;
- les identifiants des sections d'une affaire, dans l'ordre du cadre (`TICKET`,
  `front/src/lib/entites/ticket.ts`) : le vocabulaire de `sections_essentielles` ;
- la réponse simulée des catégories servies (`[CategorieServie]`), ses sections
  essentielles CALCULÉES depuis la table du serveur (`sectionsDeBase`,
  `sectionsEssentiellesParCategorie`) — jamais écrites à la main.

Depuis v3.117.0, les trois constantes du serveur se lisent dans `constantes-clients.json`
(coprofirst#2686) : `api/app/utils/saisie_affaire.py` ne se lit plus (#237, #290). Et ce
que le site écrit se lit dans `tables-clients.json` (#356) : `optionsSaisie`,
`libellesModeSaisie`, `sectionsAffaire` (son `ordre`, `SECTIONS_ORDRE` de
`entites/types.ts`, l'ordre dans lequel `TICKET` déclare ses sections) et
`categoriesTicket` — plus aucun fichier du site ne se lit ici.

→ `CoproFirst/Fonctions/Affaires/Genere/TablesSaisie.swift` et
`FixturesCategoriesServies.swift` (jugée par `scripts/verifier-fixtures.py`).
"""

from __future__ import annotations

import json

from generateurs._commun import FONCTIONS, chaine, ecrire_table

SOURCES: list[str] = []  # tables-clients.json et constantes-clients.json de la release (#356)
#: Les constantes du serveur, publiées (`constantes-clients.json`).
CONSTANTES = ("modesSaisie", "sectionsDeBase", "sectionsEssentiellesParCategorie")
GENERE = FONCTIONS / "Affaires" / "Genere"
#: L'en-tête « Source : » de `TablesSaisie.swift`, inchangé par la lecture des tables publiées
#: (la concordance compare l'en-tête au-delà de la version, #356).
PROVENANCE_TABLES = "front/src/lib/saisie-affaire.ts (OPTIONS_SAISIE, LIBELLE_MODE) et entites/ticket.ts (TICKET)"


def _objets(nom: str, valeur) -> list[dict]:
    if not (isinstance(valeur, list) and valeur and all(isinstance(v, dict) for v in valeur)):
        raise SystemExit(f"❌ {nom} : forme inattendue ({valeur!r}) — l'app doit l'apprendre")
    return valeur


def tables(ctx, modes: list[str], sections: list[str]) -> str:
    options = [o for o in _objets("optionsSaisie", ctx.table("optionsSaisie")) if o.get("val") in modes]
    if [o["val"] for o in options] != modes:
        raise SystemExit(f"❌ optionsSaisie ne décrit pas les modes du serveur {modes} dans leur ordre")
    libelles = ctx.table("libellesModeSaisie")
    if not isinstance(libelles, dict) or sorted(libelles) != sorted(modes):
        raise SystemExit(f"❌ libellesModeSaisie ({libelles!r}) ≠ modes du serveur ({modes})")
    return (
        "    /// Les choix du Profil, dans l'ordre du site : les modes que le serveur ENREGISTRE\n"
        "    /// (`MODES`) — « Selon mon rôle » n'en est pas un (coprofirst#2615).\n"
        "    static let options: [OptionSaisie] = [\n"
        + "".join(
            f"        OptionSaisie(code: {chaine(o['val'])}, libelle: {chaine(o['label'])}, "
            f"detail: {chaine(o['desc'])}),\n"
            for o in options)
        + "    ]\n"
        "    /// La phrase discrète du formulaire (`LIBELLE_MODE`).\n"
        "    static let libellesMode: [String: String] = [\n"
        + "".join(f"        {chaine(m)}: {chaine(libelles[m])},\n" for m in modes)
        + "    ]\n"
        "    /// Les sections d'une affaire, dans l'ordre du cadre (`TICKET`) : le vocabulaire de\n"
        "    /// `sections_essentielles`.\n"
        "    static let sectionsAffaire: [String] = [\n"
        + "".join(f"        {chaine(s)},\n" for s in sections)
        + "    ]\n"
    )


def fixture(ctx, base: list[str], par_categorie: dict[str, list[str]]) -> None:
    """La réponse simulée : chaque catégorie du site, telle que le serveur la sert."""
    categories = _objets("categoriesTicket", ctx.table("categoriesTicket"))
    servies = [
        {
            "code": c["value"], "libelle": c["label"], "emoji": c["emoji"], "description": c["description"],
            "carnet": bool(c.get("carnet")), "reservee": bool(c.get("reserveCS")),
            # Le compte simulé est du conseil syndical : tout lui est permis.
            "permise": True, "en_tete": bool(c.get("enTete")),
            "sections_essentielles": [*base, *par_categorie.get(c["value"], [])],
        }
        for c in categories
    ]
    inconnues = sorted(set(par_categorie) - {c["code"] for c in servies})
    if inconnues:
        raise SystemExit(f"❌ sectionsEssentiellesParCategorie cite des catégories inconnues : {inconnues}")
    lignes = ",\n".join(f"          {json.dumps(c, ensure_ascii=False)}" for c in servies)
    texte = (
        ctx.entete(f"{ctx.provenance_constantes(*CONSTANTES[1:])} ; "
                   "front/src/lib/tickets-categories.ts (CATEGORIES_TICKET)")
        + "// swiftlint:disable line_length\n\n"
        "#if DEBUG\n"
        "/// Les catégories que l'API simulée sert (`GET /tickets/referentiels` → `categories`,\n"
        "/// lues par `FixturesReferentielsAffaires`) : leurs sections essentielles CALCULÉES par\n"
        "/// le générateur depuis la table du serveur. Debug seul (#84).\n"
        "enum FixturesCategoriesServies {\n"
        "    typealias Reponse = FixturesAcces.Reponse\n\n"
        "    /// GET /tickets/referentiels → `categories`, `[CategorieServie]`.\n"
        "    static let categories = #\"\"\"\n"
        "        [\n"
        f"{lignes}\n"
        "        ]\n"
        "        \"\"\"#\n\n"
        "    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).\n"
        "    static let parSchema: [Reponse] = [\n"
        "        Reponse(nom: \"categories\", schema: \"CategorieServie\", json: categories)\n"
        "    ]\n"
        "}\n"
        "#endif\n"
        "// swiftlint:enable line_length\n"
    )
    ctx.ecrire(GENERE / "FixturesCategoriesServies.swift", texte)


def _liste(nom: str, valeur) -> list[str]:
    if not (isinstance(valeur, list) and valeur and all(isinstance(v, str) and v for v in valeur)):
        raise SystemExit(f"❌ {nom} : forme inattendue ({valeur!r}) — l'app doit l'apprendre")
    return valeur


def generer(ctx) -> str:
    modes, base = (_liste(n, ctx.constante(n)) for n in CONSTANTES[:2])
    lues = ctx.constante(CONSTANTES[2])
    if not isinstance(lues, dict):
        raise SystemExit(f"❌ {CONSTANTES[2]} : forme inattendue ({lues!r}) — l'app doit l'apprendre")
    par_categorie = {c: _liste(f"{CONSTANTES[2]}.{c}", v) for c, v in lues.items()}
    publiees = ctx.table("sectionsAffaire")
    sections = _liste("sectionsAffaire.ordre", publiees.get("ordre") if isinstance(publiees, dict) else None)
    hors_cadre = sorted({s for liste in [base, *par_categorie.values()] for s in liste} - set(sections))
    if hors_cadre:
        raise SystemExit(f"❌ sections essentielles hors du cadre TICKET : {hors_cadre}")
    ecrire_table(ctx, GENERE / "TablesSaisie.swift",
                 f"{PROVENANCE_TABLES} ; {ctx.provenance_constantes(CONSTANTES[0])}", "TablesSaisie",
                 "La saisie d'une affaire, Essentielle ou Complète : ce que le contrat ne sert pas.",
                 tables(ctx, modes, sections))
    fixture(ctx, base, par_categorie)
    return f"{len(modes)} modes de saisie ; {len(sections)} sections d'une affaire ; {len(par_categorie)} catégories enrichies"
