# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Combien de temps reste la phrase brève qui suit un geste (le « toast » du site) :
la durée par défaut de `toast()` (table `dureeToastMs`)
→ `CoproFirst/Charte/AvisDuSite.swift`, lue par `AvisEphemere` (Commun/Composants).

Écrite à la main, elle avait divergé (2,5 s dans l'app, 4 s sur le site) : un avis
annoncé pendant qu'une feuille se ferme n'était plus là quand on le cherchait (#15).
"""

from __future__ import annotations

from generateurs._commun import CHARTE
from generateurs._tables import source

SOURCES: list[str] = []


def generer(ctx) -> str:
    millisecondes = ctx.table("dureeToastMs", int)
    if millisecondes < 1:
        raise SystemExit(f"❌ dureeToastMs : une durée d'au moins 1 ms est attendue, {millisecondes} lu")
    corps = ctx.entete(source("dureeToastMs"))
    corps += "\n/// L'avis qui suit un geste, comme le site le montre.\n"
    corps += "enum AvisDuSite {\n"
    corps += "    /// Le temps qu'il reste à l'écran (`duration` par défaut de `toast()`).\n"
    corps += f"    static let duree: Duration = .milliseconds({millisecondes})\n"
    corps += "}\n"
    ctx.ecrire(CHARTE / "AvisDuSite.swift", corps)
    return f"avis de {millisecondes} ms"
