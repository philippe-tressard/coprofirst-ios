# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Le texte du bandeau « installation suspendue » (Registre R6, coprofirst#1882, #262),
lu dans la table que la release publie (`bandeauSuspendue`, de
`front/src/lib/bandeaux-installation.ts`) — littérale, entière, jamais recopiée.

Le site le compose `titre` + `SEPARATEUR.tiret` + `precision` + « . », en gras, suivi du
`texte` ; l'app aussi (`BandeauInstallation`). Une clé retirée par le site fait échouer le
build là où l'app l'emploie.

→ `CoproFirst/Commun/Composants/Genere/TexteBandeauSuspendue.swift`.
"""

from __future__ import annotations

import pathlib

from generateurs._commun import chaine, ecrire_table

SOURCES: list[str] = []  # bandeauSuspendue de tables-clients.json
SORTIE = pathlib.Path("CoproFirst/Commun/Composants/Genere/TexteBandeauSuspendue.swift")
CLES = ("titre", "precision", "texte")


def generer(ctx) -> str:
    publie = ctx.table("bandeauSuspendue")
    if not isinstance(publie, dict) or set(publie) != set(CLES) or not all(
            isinstance(publie[c], str) and publie[c].strip() for c in CLES):
        raise SystemExit(f"❌ bandeauSuspendue : forme inattendue (clés attendues : {', '.join(CLES)}) — "
                         "l'app doit l'apprendre")
    corps = "".join(f"    /// `BANDEAU_SUSPENDUE.{cle}`\n    static let {cle} = {chaine(publie[cle])}\n" for cle in CLES)
    ecrire_table(ctx, SORTIE, ctx.provenance_tables("bandeauSuspendue"), "TexteBandeauSuspendue",
                 "Le bandeau d'une installation suspendue par la référence, en lecture seule (R6).", corps)
    return f"bandeau « {publie['titre']} »"
