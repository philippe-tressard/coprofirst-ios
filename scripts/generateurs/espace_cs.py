# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que le site écrit de l'Espace conseil syndical et que le contrat ne sert pas (#15),
lu dans `tables-clients.json` de la release (#128) :

- le descriptif de chaque onglet de la page `espace-cs` (table `pages`) — les onglets
  eux-mêmes, leur ordre et leur réserve sont dans `Charte/OngletsDuSite.swift` ;
- les civilités d'une fiche de l'annuaire (table `civilites`).

→ `CoproFirst/Fonctions/EspaceCS/Genere/TablesEspaceCS.swift`.
"""

from __future__ import annotations

from generateurs._commun import FONCTIONS, chaine, ecrire_table

SOURCES: list[str] = []  # lu dans tables-clients.json de la release (#128), pas dans les sources


def generer(ctx) -> str:
    page = next((p for p in ctx.table("pages") if p.get("id") == "espace-cs"), None)
    if page is None:
        raise SystemExit("❌ la page espace-cs a disparu de la table pages")
    descriptifs = [(o["id"], o["descriptif"]) for o in page.get("onglets") or [] if o.get("descriptif")]
    civilites = ctx.table("civilites")
    if not isinstance(civilites, list) or not all(isinstance(c, str) and c for c in civilites):
        raise SystemExit(f"❌ la table civilites change de forme : {civilites!r}")
    corps = (
        "    /// Le descriptif de chaque onglet de la page `espace-cs` (texte du site).\n"
        "    static let descriptifs: [String: String] = [\n"
        + "".join(f"        {chaine(i)}: {chaine(d)},\n" for i, d in descriptifs)
        + "    ]\n"
        "    /// Les civilités d'une fiche de l'annuaire, dans l'ordre du site (`CIVILITES`).\n"
        f"    static let civilites: [String] = [{', '.join(chaine(c) for c in civilites)}]\n"
    )
    ecrire_table(ctx, FONCTIONS / "EspaceCS" / "Genere" / "TablesEspaceCS.swift",
                 f"{ctx.source_table('pages')}, {ctx.source_table('civilites')} (tables-clients.json)",
                 "TablesEspaceCS",
                 "Ce que le site écrit de l'Espace conseil syndical et que le contrat ne sert pas.", corps)
    return f"{len(descriptifs)} descriptifs d'onglets ; {len(civilites)} civilités"
