# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les options de MISE EN AVANT d'une affaire — l'épinglage et l'urgence : celles que
le site offre à une affaire (`OPTIONS_TICKET`, `tickets.ts`), avec leurs mots
(`OPTIONS_PUBLICATION`, `options-publication.ts`) → `CoproFirst/Charte/OptionsDuSite.swift`,
lu par le menu Options du bandeau d'une affaire (`Commun/Detail/Affaire/`).
"""

from __future__ import annotations

import re

import lecture_ts
from generateurs._commun import CHARTE, chaine, ecrire_table

SOURCES = ["front/src/lib/tickets.ts", "front/src/lib/options-publication.ts"]


def generer(ctx) -> str:
    m = re.search(r"\bconst OPTIONS_TICKET\b[^=]*=\s*\[([^\]]*)\]", ctx.lire(SOURCES[0]))
    if not m:
        raise SystemExit("❌ OPTIONS_TICKET introuvable dans tickets.ts")
    cles = re.findall(r"'([^']+)'", m.group(1))
    options = {o["cle"]: o for o in lecture_ts.table(ctx.lire(SOURCES[1]), "OPTIONS_PUBLICATION")}
    manquantes = [c for c in cles if c not in options]
    if manquantes:
        raise SystemExit(f"❌ OPTIONS_PUBLICATION ne décrit pas {manquantes}")
    lignes = "".join(
        f"        Option(\n"
        f"            cle: {chaine(c)}, action: {chaine(options[c]['action'])}, etat: {chaine(options[c]['etat'])},\n"
        f"            aide: {chaine(options[c]['aide'])}),\n"
        for c in cles
    )
    corps = (
        "    /// Une option : la clé (le champ de `TicketUpdate`), le verbe, l'état actif, et ce\n"
        "    /// qu'elle fait.\n"
        "    struct Option: Hashable, Sendable {\n"
        "        let cle: String\n"
        "        let action: String\n"
        "        let etat: String\n"
        "        let aide: String\n"
        "    }\n\n"
        "    /// Dans l'ordre du site.\n"
        "    static let affaire: [Option] = [\n"
        + lignes
        + "    ]\n"
    )
    ecrire_table(ctx, CHARTE / "OptionsDuSite.swift", "front/src/lib/tickets.ts (OPTIONS_TICKET), "
                 "options-publication.ts (OPTIONS_PUBLICATION)", "OptionsDuSite",
                 "Les options de mise en avant d'une affaire, comme le site les nomme.", corps)
    return f"{len(cles)} options d'une affaire"
