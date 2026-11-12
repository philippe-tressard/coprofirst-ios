# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les tables de « Mes lots & accès » et de « Prestataires » (#13).

Le contrat d'API ne sert que des CODES (`StatutAcces`, `StatutBail`,
`TypePrestataire`) : les libellés et les teintes sont ceux que le site publie
(`tables-clients.json`) :

- le descriptif des onglets de `mon-lot` et `prestataires` (table `pages`) — les onglets
  eux-mêmes sont dans `Charte/OngletsDuSite.swift` (#30) ;
- `statutsAcces` et `typesAcces` ;
- l'état d'un bail (`etatsBail`) ;
- `typesPrestataire` et `filtresContrat`.

→ `CoproFirst/Fonctions/Acces/Genere/TablesAcces.swift` et
`CoproFirst/Fonctions/Prestataires/Genere/TablesPrestataires.swift`.
"""

from __future__ import annotations

from generateurs._commun import ATTRIBUTS, FONCTIONS, OPTION, chaine, couples, ecrire_table, page_du_site, teintes
from generateurs._tables import source

SOURCES: list[str] = []


def descriptifs(ctx, identifiant: str) -> str:
    """Le descriptif de chaque onglet de la page (table `pages`). Les onglets eux-mêmes —
    libellé, ordre, réserve — sont générés une fois pour toute l'app :
    `Charte/OngletsDuSite.swift` (#30)."""
    onglets = page_du_site(ctx, identifiant).get("onglets") or []
    if not onglets:
        raise SystemExit(f"❌ la page {identifiant} n'a plus d'onglets dans la table « pages »")
    lignes = "".join(f"        {chaine(o['id'])}: {chaine(o.get('descriptif', ''))},\n" for o in onglets)
    return (
        f"    /// Le descriptif de chaque onglet de la page `{identifiant}` (texte du site, parfois HTML).\n"
        "    static let descriptifs: [String: String] = [\n" + lignes + "    ]\n"
    )


def options(ctx, table: str) -> list[tuple[str, str]]:
    return [(e["val"], e["label"]) for e in ctx.table(table, [OPTION])]


def acces(ctx) -> str:
    statuts = [(s["val"], s["label"], s["badge"]) for s in ctx.table("statutsAcces", [{**OPTION, "badge": str}])]
    bail = ctx.table("etatsBail", ATTRIBUTS)
    return (
        descriptifs(ctx, "mon-lot")
        + teintes("statutsAcces", "L'état d'un badge ou d'une télécommande (`STATUTS_ACCES`).", statuts)
        + couples("typesAcces", "Les deux familles d'accès, dans l'ordre du site (`TYPES_ACCES`).",
                  options(ctx, "typesAcces"))
        + teintes("statutsBail", "L'état d'un bail (`ETATS_BAIL`).",
                  [(c, v["libelle"], v["badge"]) for c, v in bail.items()])
    )


def prestataires(ctx) -> str:
    types = "".join(
        f"        TypePrestataire(code: {chaine(t['val'])}, libelle: {chaine(t['label'])}, "
        f"description: {chaine(t['desc'])}),\n"
        for t in ctx.table("typesPrestataire", [{**OPTION, "desc": str}]))
    return (
        descriptifs(ctx, "prestataires")
        + "    /// Les catégories de prestataires, dans l'ordre du site (`TYPES_PRESTATAIRE`).\n"
        "    static let types: [TypePrestataire] = [\n" + types + "    ]\n"
        + couples("filtresContrat", "Le filtre « Contrat » (`FILTRES_CONTRAT`).", options(ctx, "filtresContrat"))
    )


def generer(ctx) -> str:
    ecrire_table(ctx, FONCTIONS / "Acces" / "Genere" / "TablesAcces.swift",
                 source("pages", "statutsAcces", "typesAcces", "etatsBail"), "TablesAcces",
                 "Ce que le site écrit de « Mes lots & accès » et que le contrat ne sert pas.", acces(ctx))
    ecrire_table(ctx, FONCTIONS / "Prestataires" / "Genere" / "TablesPrestataires.swift",
                 source("pages", "typesPrestataire", "filtresContrat"), "TablesPrestataires",
                 "Ce que le site écrit de « Prestataires » et que le contrat ne sert pas.", prestataires(ctx))
    return "accès, baux et prestataires"
