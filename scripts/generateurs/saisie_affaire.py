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
(coprofirst#2686) : `api/app/utils/saisie_affaire.py` ne se lit plus (#237, #290).

→ `CoproFirst/Fonctions/Affaires/Genere/TablesSaisie.swift` et
`FixturesCategoriesServies.swift` (jugée par `scripts/verifier-fixtures.py`).
"""

from __future__ import annotations

import json
import re

import lecture_ts
from generateurs._commun import FONCTIONS, chaine, ecrire_table

SOURCES = [
    "front/src/lib/saisie-affaire.ts",
    "front/src/lib/entites/ticket.ts",
    "front/src/lib/tickets-categories.ts",
]
#: Les constantes du serveur, publiées (`constantes-clients.json`).
CONSTANTES = ("modesSaisie", "sectionsDeBase", "sectionsEssentiellesParCategorie")
GENERE = FONCTIONS / "Affaires" / "Genere"
#: Une section du cadre d'une affaire : `id: '…'` au troisième retrait de `sections: [`.
SECTION = re.compile(r"^\t\t\tid: '([a-z_]+)',", re.M)


def libelles_mode(texte: str) -> dict[str, str]:
    m = re.search(r"\bconst LIBELLE_MODE\b[^=]*=\s*\{(.*?)\};", texte, re.S)
    if not m:
        raise SystemExit("❌ LIBELLE_MODE introuvable dans saisie-affaire.ts")
    return dict(re.findall(r"(\w+):\s*'([^']*)'", m.group(1)))


def tables(ctx, modes: list[str], sections: list[str]) -> str:
    front = ctx.lire(SOURCES[0])
    options = [o for o in lecture_ts.table(front, "OPTIONS_SAISIE") if o["val"] in modes]
    if [o["val"] for o in options] != modes:
        raise SystemExit(f"❌ OPTIONS_SAISIE ne décrit pas les modes du serveur {modes} dans leur ordre")
    libelles = libelles_mode(front)
    if sorted(libelles) != sorted(modes):
        raise SystemExit(f"❌ LIBELLE_MODE ({sorted(libelles)}) ≠ modes du serveur ({modes})")
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
    categories = lecture_ts.table(ctx.lire(SOURCES[2]), "CATEGORIES_TICKET")
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
    sections = SECTION.findall(ctx.lire(SOURCES[1]))
    if not sections:
        raise SystemExit("❌ ticket.ts : aucune section `id: '…'` lue — la source a changé")
    hors_cadre = sorted({s for liste in [base, *par_categorie.values()] for s in liste} - set(sections))
    if hors_cadre:
        raise SystemExit(f"❌ sections essentielles hors du cadre TICKET : {hors_cadre}")
    ecrire_table(ctx, GENERE / "TablesSaisie.swift",
                 "front/src/lib/saisie-affaire.ts (OPTIONS_SAISIE, LIBELLE_MODE) et entites/ticket.ts (TICKET) ; "
                 + ctx.provenance_constantes(CONSTANTES[0]), "TablesSaisie",
                 "La saisie d'une affaire, Essentielle ou Complète : ce que le contrat ne sert pas.",
                 tables(ctx, modes, sections))
    fixture(ctx, base, par_categorie)
    return f"{len(modes)} modes de saisie ; {len(sections)} sections d'une affaire ; {len(par_categorie)} catégories enrichies"
