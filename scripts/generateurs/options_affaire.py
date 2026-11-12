# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les options de MISE EN AVANT d'une affaire — l'épinglage et l'urgence : celles que
le site offre à une affaire (table `optionsTicket`), avec leurs mots (table
`optionsPublication`) → `CoproFirst/Charte/OptionsDuSite.swift`, lu par le menu Options
du bandeau d'une affaire (`Commun/Detail/Affaire/`).
"""

from __future__ import annotations

from generateurs._commun import CHARTE, chaine, ecrire_table
from generateurs._tables import source

SOURCES: list[str] = []


def generer(ctx) -> str:
    cles = ctx.table("optionsTicket", [str])
    decrites = ctx.table("optionsPublication", [{"cle": str, "action": str, "etat": str, "aide": str}])
    options = {o["cle"]: o for o in decrites}
    manquantes = [c for c in cles if c not in options]
    if manquantes:
        raise SystemExit(f"❌ optionsPublication ne décrit pas {manquantes}")
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
    ecrire_table(ctx, CHARTE / "OptionsDuSite.swift", source("optionsTicket", "optionsPublication"), "OptionsDuSite",
                 "Les options de mise en avant d'une affaire, comme le site les nomme.", corps)
    return f"{len(cles)} options d'une affaire"
