# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Combien de temps reste la phrase brève qui suit un geste (le « toast » du site) :
la durée par défaut de `toast()` (`front/src/lib/components/Toast.svelte`)
→ `CoproFirst/Charte/AvisDuSite.swift`, lue par `AvisEphemere` (Commun/Composants).

Écrite à la main, elle avait divergé (2,5 s dans l'app, 4 s sur le site) : un avis
annoncé pendant qu'une feuille se ferme n'était plus là quand on le cherchait (#15).
"""

from __future__ import annotations

import re

from generateurs._commun import CHARTE

SOURCES = ["front/src/lib/components/Toast.svelte"]


def generer(ctx) -> str:
    texte = (ctx.front / SOURCES[0].removeprefix("front/")).read_text(encoding="utf-8")
    m = re.search(r"export function toast\([^)]*duration = (\d+)\)", texte)
    if not m:
        raise SystemExit("❌ la durée par défaut de toast() est introuvable dans Toast.svelte")
    millisecondes = int(m.group(1))
    corps = ctx.entete("front/src/lib/components/Toast.svelte (toast)")
    corps += "\n/// L'avis qui suit un geste, comme le site le montre.\n"
    corps += "enum AvisDuSite {\n"
    corps += "    /// Le temps qu'il reste à l'écran (`duration` par défaut de `toast()`).\n"
    corps += f"    static let duree: Duration = .milliseconds({millisecondes})\n"
    corps += "}\n"
    ctx.ecrire(CHARTE / "AvisDuSite.swift", corps)
    return f"avis de {millisecondes} ms"
