# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Combien de temps reste la phrase brève qui suit un geste (le « toast » du site) :
`dureeToastMs` de `tables-clients.json` (`DUREE_TOAST_MS` de `front/src/lib/toast.ts`)
→ `CoproFirst/Charte/AvisDuSite.swift`, lue par `AvisEphemere` (Commun/Composants).

Écrite à la main, elle avait divergé (2,5 s dans l'app, 4 s sur le site) : un avis
annoncé pendant qu'une feuille se ferme n'était plus là quand on le cherchait (#15).
"""

from __future__ import annotations

from generateurs._commun import CHARTE

SOURCES: list[str] = []  # lu dans tables-clients.json de la release (#128), pas dans les sources


def generer(ctx) -> str:
    millisecondes = ctx.table("dureeToastMs")
    if not isinstance(millisecondes, int) or millisecondes <= 0:
        raise SystemExit(f"❌ dureeToastMs n'est pas une durée en millisecondes : {millisecondes!r}")
    corps = ctx.entete(ctx.provenance_tables("dureeToastMs"))
    corps += "\n/// L'avis qui suit un geste, comme le site le montre.\n"
    corps += "enum AvisDuSite {\n"
    corps += "    /// Le temps qu'il reste à l'écran (`DUREE_TOAST_MS` du site).\n"
    corps += f"    static let duree: Duration = .milliseconds({millisecondes})\n"
    corps += "}\n"
    ctx.ecrire(CHARTE / "AvisDuSite.swift", corps)
    return f"avis de {millisecondes} ms"
