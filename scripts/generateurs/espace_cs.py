# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que le site écrit de l'Espace conseil syndical et que le contrat ne sert pas (#15) :

- le descriptif de chaque onglet de la page `espace-cs` (`pages-roles.ts`) — les onglets
  eux-mêmes, leur ordre et leur réserve sont dans `Charte/OngletsDuSite.swift` ;
- les civilités d'une fiche de l'annuaire (`CIVILITES` de `CarteMembre.svelte`).

→ `CoproFirst/Fonctions/EspaceCS/Genere/TablesEspaceCS.swift`.
"""

from __future__ import annotations

import pathlib
import re

from generateurs._commun import FONCTIONS, chaine, ecrire_table, tables_des_pages

SOURCES = [
    "front/src/lib/pages-roles.ts",
    "front/src/lib/components/CarteMembre.svelte",
]


def _civilites(front: pathlib.Path) -> list[str]:
    texte = (front / "src/lib/components/CarteMembre.svelte").read_text(encoding="utf-8")
    m = re.search(r"export const CIVILITES = \[([^\]]*)\]", texte)
    if not m:
        raise SystemExit("❌ CIVILITES introuvable dans CarteMembre.svelte — l'app doit l'apprendre")
    return re.findall(r"'([^']+)'", m.group(1))


def generer(ctx) -> str:
    _, roles = tables_des_pages(ctx.front)
    page = next((p for p in roles if p.get("id") == "espace-cs"), None)
    if page is None:
        raise SystemExit("❌ la page espace-cs a disparu de PAGES_ROLES")
    descriptifs = [(o["id"], o["descriptif"]) for o in page.get("onglets") or [] if o.get("descriptif")]
    civilites = _civilites(ctx.front)
    corps = (
        "    /// Le descriptif de chaque onglet de la page `espace-cs` (texte du site).\n"
        "    static let descriptifs: [String: String] = [\n"
        + "".join(f"        {chaine(i)}: {chaine(d)},\n" for i, d in descriptifs)
        + "    ]\n"
        "    /// Les civilités d'une fiche de l'annuaire, dans l'ordre du site (`CIVILITES`).\n"
        f"    static let civilites: [String] = [{', '.join(chaine(c) for c in civilites)}]\n"
    )
    ecrire_table(ctx, FONCTIONS / "EspaceCS" / "Genere" / "TablesEspaceCS.swift",
                 "front/src/lib/pages-roles.ts, components/CarteMembre.svelte", "TablesEspaceCS",
                 "Ce que le site écrit de l'Espace conseil syndical et que le contrat ne sert pas.", corps)
    return f"{len(descriptifs)} descriptifs d'onglets ; {len(civilites)} civilités"
