# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que le site écrit de l'Espace conseil syndical et que le contrat ne sert pas (#15),
lu dans `tables-clients.json` de la release (#128) :

- le descriptif et l'adresse de chaque onglet de la page `espace-cs` (table `pages`) —
  « Sur le site » renvoie à ceux que l'app ne porte pas (les écrans du hall) ; les
  onglets eux-mêmes, leur ordre et leur réserve sont dans `Charte/OngletsDuSite.swift` ;
- les civilités d'une fiche de l'annuaire (table `civilites`).

→ `CoproFirst/Fonctions/EspaceCS/Genere/TablesEspaceCS.swift`.
"""

from __future__ import annotations

from generateurs._commun import FONCTIONS, chaine, ecrire_table, page_a_onglets

SOURCES: list[str] = []  # lu dans tables-clients.json de la release (#128), pas dans les sources


def generer(ctx) -> str:
    onglets, onglets_lus = page_a_onglets(ctx, "espace-cs")
    civilites = ctx.table("civilites")
    if not isinstance(civilites, list) or not all(isinstance(c, str) and c for c in civilites):
        raise SystemExit(f"❌ la table civilites change de forme : {civilites!r}")
    corps = (
        onglets_lus
        + "    /// Les civilités d'une fiche de l'annuaire, dans l'ordre du site (`CIVILITES`).\n"
        f"    static let civilites: [String] = [{', '.join(chaine(c) for c in civilites)}]\n"
    )
    ecrire_table(ctx, FONCTIONS / "EspaceCS" / "Genere" / "TablesEspaceCS.swift",
                 f"{ctx.source_table('pages')}, {ctx.source_table('civilites')} (tables-clients.json)",
                 "TablesEspaceCS",
                 "Ce que le site écrit de l'Espace conseil syndical et que le contrat ne sert pas.", corps)
    return f"{len(onglets)} onglets et leur adresse ; {len(civilites)} civilités"
