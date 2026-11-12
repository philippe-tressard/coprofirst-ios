# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que le site écrit de l'Espace conseil syndical et que le contrat ne sert pas (#15) :

- le descriptif de chaque onglet de la page `espace-cs` (table `pages`) — les onglets
  eux-mêmes, leur ordre et leur réserve sont dans `Charte/OngletsDuSite.swift` ;
- les civilités d'une fiche de l'annuaire (table `civilites`).

→ `CoproFirst/Fonctions/EspaceCS/Genere/TablesEspaceCS.swift`.
"""

from __future__ import annotations

from generateurs._commun import FONCTIONS, chaine, dictionnaire, ecrire_table, page_du_site
from generateurs._tables import source

SOURCES: list[str] = []


def generer(ctx) -> str:
    onglets = page_du_site(ctx, "espace-cs").get("onglets") or []
    descriptifs = {o["id"]: o["descriptif"] for o in onglets if o.get("descriptif")}
    if not descriptifs:
        raise SystemExit("❌ la page espace-cs n'a plus d'onglet décrit dans la table « pages »")
    civilites = ctx.table("civilites", [str])
    corps = (
        dictionnaire("descriptifs", "Le descriptif de chaque onglet de la page `espace-cs` (texte du site).",
                     descriptifs)
        + "    /// Les civilités d'une fiche de l'annuaire, dans l'ordre du site (`CIVILITES`).\n"
        f"    static let civilites: [String] = [{', '.join(chaine(c) for c in civilites)}]\n"
    )
    ecrire_table(ctx, FONCTIONS / "EspaceCS" / "Genere" / "TablesEspaceCS.swift",
                 source("pages", "civilites"), "TablesEspaceCS",
                 "Ce que le site écrit de l'Espace conseil syndical et que le contrat ne sert pas.", corps)
    return f"{len(descriptifs)} descriptifs d'onglets ; {len(civilites)} civilités"
