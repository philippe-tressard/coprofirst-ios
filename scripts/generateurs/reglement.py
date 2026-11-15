# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que le site écrit de l'avis sur le règlement et que le contrat ne sert pas (#71) :
la classe de la capsule du verdict pour chaque ton SERVI (`verdict_ton`, #2505) —
`BadgeVerdict.svelte` la choisit ; le serveur dit le ton, le front le peint. Le
séparateur des repères d'un extrait est celui de tout le site (`separateurs.py`, #188).

→ `CoproFirst/Fonctions/Residence/Genere/TablesReglement.swift`.
"""

from __future__ import annotations

import re

from generateurs._commun import FONCTIONS, chaine, ecrire_table

SOURCES = ["front/src/lib/components/BadgeVerdict.svelte"]


def _badges(texte: str) -> tuple[dict[str, str], str]:
    """Les tons nommés (`class:badge-x={ton === 'y'}`), et la classe de tout autre ton."""
    tons = {ton: f"badge-{teinte}" for teinte, ton in re.findall(r"class:badge-([\w-]+)=\{ton === '(\w+)'\}", texte)}
    autres = re.findall(r"class:badge-([\w-]+)=\{ton !== ", texte)
    if not tons or len(autres) != 1:
        raise SystemExit("❌ les teintes du verdict sont illisibles dans BadgeVerdict.svelte — l'app doit l'apprendre")
    return tons, f"badge-{autres[0]}"



def generer(ctx) -> str:
    tons, inconnu = _badges(ctx.lire(SOURCES[0]))
    corps = (
        "    /// La classe de la capsule du verdict, pour chaque ton servi (`BadgeVerdict.svelte`).\n"
        "    static let badgesDuVerdict: [String: String] = [\n"
        + "".join(f"        {chaine(t)}: {chaine(b)},\n" for t, b in tons.items())
        + "    ]\n"
        "    /// Un ton absent ou inconnu : le site le lit incertain.\n"
        f"    static let badgeDuVerdictInconnu = {chaine(inconnu)}\n"
    )
    ecrire_table(ctx, FONCTIONS / "Residence" / "Genere" / "TablesReglement.swift",
                 "front/src/lib/components/BadgeVerdict.svelte", "TablesReglement",
                 "Ce que le site écrit de l'avis sur le règlement et que le contrat ne sert pas.", corps)
    return f"{len(tons)} tons du verdict"
