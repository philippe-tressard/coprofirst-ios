# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que le site écrit de l'avis sur le règlement et que le contrat ne sert pas (#71) :
la classe de la capsule du verdict pour chaque ton SERVI (`verdict_ton`, #2505) —
`BadgeVerdict.svelte` la choisit ; le serveur dit le ton, le front le peint. Le
séparateur des repères d'un extrait est celui de tout le site (`separateurs.py`, #188).

Depuis v3.105.0, la release PUBLIE cette table (`badgesDuVerdict`, tables-clients.json
1.3.0) : elle se lit là. Sous v3.105.0 (le plancher v3.103.0), un REPLI lit encore
`BadgeVerdict.svelte` par motif — sans lui, la concordance de montée devenait INCONNUE
(#237). Le repli échoue de lui-même dès que le plancher atteint v3.105.0 : le retirer (#239).

→ `CoproFirst/Fonctions/Residence/Genere/TablesReglement.swift`.
"""

from __future__ import annotations

import re

from generateurs import _plancher
from generateurs._commun import FONCTIONS, chaine, ecrire_table

SOURCES = ["front/src/lib/components/BadgeVerdict.svelte"]
#: La première version qui publie `badgesDuVerdict` : le repli par motif s'arrête là.
PUBLIEE_DEPUIS = (3, 105, 0)


def _version(etiquette: str) -> tuple[int, ...]:
    return tuple(int(n) for n in etiquette.lstrip("v").split("."))


def _badges(texte: str) -> tuple[dict[str, str], str]:
    """Les tons nommés (`class:badge-x={ton === 'y'}`), et la classe de tout autre ton."""
    tons = {ton: f"badge-{teinte}" for teinte, ton in re.findall(r"class:badge-([\w-]+)=\{ton === '(\w+)'\}", texte)}
    autres = re.findall(r"class:badge-([\w-]+)=\{ton !== ", texte)
    if not tons or len(autres) != 1:
        raise SystemExit("❌ les teintes du verdict sont illisibles dans BadgeVerdict.svelte — l'app doit l'apprendre")
    return tons, f"badge-{autres[0]}"



def generer(ctx) -> str:
    if _version(_plancher.VERSION) >= PUBLIEE_DEPUIS:
        raise SystemExit("❌ le plancher publie badgesDuVerdict : retirer le repli par BadgeVerdict.svelte "
                         "et sa source de reglement.py (#239)")
    if ctx.publie("badgesDuVerdict"):
        publiee = ctx.table("badgesDuVerdict")
        tons, inconnu, source = dict(publiee["parTon"]), publiee["inconnu"], ctx.provenance_tables("badgesDuVerdict")
    else:
        tons, inconnu = _badges(ctx.lire(SOURCES[0]))
        source = SOURCES[0]
    corps = (
        "    /// La classe de la capsule du verdict, pour chaque ton servi (`BadgeVerdict.svelte`).\n"
        "    static let badgesDuVerdict: [String: String] = [\n"
        + "".join(f"        {chaine(t)}: {chaine(b)},\n" for t, b in tons.items())
        + "    ]\n"
        "    /// Un ton absent ou inconnu : le site le lit incertain.\n"
        f"    static let badgeDuVerdictInconnu = {chaine(inconnu)}\n"
    )
    ecrire_table(ctx, FONCTIONS / "Residence" / "Genere" / "TablesReglement.swift",
                 source, "TablesReglement",
                 "Ce que le site écrit de l'avis sur le règlement et que le contrat ne sert pas.", corps)
    return f"{len(tons)} tons du verdict"
