# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les tables de « Mes lots & accès » et de « Prestataires » (#13).

Le contrat d'API ne sert que des CODES (`StatutAcces`, `StatutBail`,
`TypePrestataire`) : les libellés et les teintes vivent dans le front du site, qui les
publie dans `tables-clients.json` de chaque release (#128) :

- le descriptif des onglets de `mon-lot` et `prestataires` (`pages`) — les onglets
  eux-mêmes sont dans `Charte/OngletsDuSite.swift` (#30) ;
- `statutsAcces` et `typesAcces` (`types-acces.ts`) ;
- l'état d'un bail (`etatsBail`, `ETATS_BAIL` de `bail.ts`) ;
- `typesPrestataire` et `filtresContrat` (`prestataires.ts`).

→ `CoproFirst/Fonctions/Acces/Genere/TablesAcces.swift` et
`CoproFirst/Fonctions/Prestataires/Genere/TablesPrestataires.swift`.
"""

from __future__ import annotations

from generateurs._commun import FONCTIONS, chaine, ecrire_table

SOURCES: list[str] = []  # lu dans tables-clients.json de la release (#128), pas dans les sources


def page(ctx, identifiant: str) -> dict:
    return next(p for p in ctx.table("pages") if p["id"] == identifiant)


def descriptifs(ctx, identifiant: str) -> str:
    """Le descriptif de chaque onglet de la page (`pages`). Les onglets eux-mêmes —
    libellé, ordre, réserve — sont générés une fois pour toute l'app :
    `Charte/OngletsDuSite.swift` (#30)."""
    lignes = "".join(
        f"        {chaine(o['id'])}: {chaine(o.get('descriptif', ''))},\n" for o in page(ctx, identifiant)["onglets"])
    return (
        f"    /// Le descriptif de chaque onglet de la page `{identifiant}` (texte du site, parfois HTML).\n"
        "    static let descriptifs: [String: String] = [\n" + lignes + "    ]\n"
    )


def teintes(nom: str, entrees: list[tuple[str, str, str]], doc: str) -> str:
    lignes = "".join(f"        {chaine(c)}: LibelleTeinte({chaine(l)}, {chaine(b)}),\n" for c, l, b in entrees)
    return f"    /// {doc}\n    static let {nom}: [String: LibelleTeinte] = [\n{lignes}    ]\n"


def acces(ctx) -> str:
    statuts = [(s["val"], s["label"], s["badge"]) for s in ctx.table("statutsAcces")]
    types = "".join(f"        ({chaine(t['val'])}, {chaine(t['label'])}),\n" for t in ctx.table("typesAcces"))
    bail = ctx.table("etatsBail")
    return (
        descriptifs(ctx, "mon-lot")
        + teintes("statutsAcces", statuts, "L'état d'un badge ou d'une télécommande (`STATUTS_ACCES`).")
        + "    /// Les deux familles d'accès, dans l'ordre du site (`TYPES_ACCES`).\n"
        "    static let typesAcces: [(code: String, libelle: String)] = [\n" + types + "    ]\n"
        + teintes("statutsBail", [(c, v["libelle"], v["badge"]) for c, v in bail.items()],
                  "L'état d'un bail (`ETATS_BAIL`).")
    )


def prestataires(ctx) -> str:
    types = "".join(
        f"        TypePrestataire(code: {chaine(t['val'])}, libelle: {chaine(t['label'])}, "
        f"description: {chaine(t['desc'])}),\n"
        for t in ctx.table("typesPrestataire"))
    filtres = "".join(f"        ({chaine(f['val'])}, {chaine(f['label'])}),\n" for f in ctx.table("filtresContrat"))
    return (
        descriptifs(ctx, "prestataires")
        + "    /// Les catégories de prestataires, dans l'ordre du site (`TYPES_PRESTATAIRE`).\n"
        "    static let types: [TypePrestataire] = [\n" + types + "    ]\n"
        "    /// Le filtre « Contrat » (`FILTRES_CONTRAT`).\n"
        "    static let filtresContrat: [(code: String, libelle: String)] = [\n" + filtres + "    ]\n"
    )


def generer(ctx) -> str:
    ecrire_table(ctx, FONCTIONS / "Acces" / "Genere" / "TablesAcces.swift",
                 ctx.provenance_tables("pages", "statutsAcces", "typesAcces", "etatsBail"), "TablesAcces",
                 "Ce que le site écrit de « Mes lots & accès » et que le contrat ne sert pas.", acces(ctx))
    ecrire_table(ctx, FONCTIONS / "Prestataires" / "Genere" / "TablesPrestataires.swift",
                 ctx.provenance_tables("pages", "typesPrestataire", "filtresContrat"), "TablesPrestataires",
                 "Ce que le site écrit de « Prestataires » et que le contrat ne sert pas.", prestataires(ctx))
    return "accès, baux et prestataires"
