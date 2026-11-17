# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que le site écrit de l'avis sur le règlement et que le contrat ne sert pas (#71) :
la classe de la capsule du verdict pour chaque ton SERVI (`verdict_ton`, #2505) —
`BadgeVerdict.svelte` la choisit ; le serveur dit le ton, le front le peint. Le
séparateur des repères d'un extrait est celui de tout le site (`separateurs.py`, #188).

La release PUBLIE cette table depuis v3.105.0 (`badgesDuVerdict`, tables-clients.json
1.3.0) : elle se lit là, plus dans `BadgeVerdict.svelte` par motif (#239) ; `generer.py`
refuse le retour de cette source.

→ `CoproFirst/Fonctions/Residence/Genere/TablesReglement.swift`.
"""

from __future__ import annotations

from generateurs._commun import FONCTIONS, chaine, ecrire_table

SOURCES: list[str] = []  # badgesDuVerdict de tables-clients.json (#239)


def generer(ctx) -> str:
    publiee = ctx.table("badgesDuVerdict")
    tons, inconnu = dict(publiee["parTon"]), publiee["inconnu"]
    if not tons or not isinstance(inconnu, str):
        raise SystemExit("❌ badgesDuVerdict : forme inattendue — l'app doit l'apprendre")
    source = ctx.provenance_tables("badgesDuVerdict")
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
