# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""La notation d'un prestataire, telle que le site l'écrit (#207).

Le serveur sert l'ÉTAT d'un avis (`etat` : `mauvais`, `neutre`, `excellent`) et la
moyenne d'un prestataire (`note_moyenne`) ; le site en tient le libellé, la teinte et
les seuils qui disent l'état d'une moyenne (`etatDeMoyenne`) — cette table est « la
SEULE du front ». Depuis v3.106.0, elle se lit dans `tables-clients.json` (`notations`,
coprofirst#2775) — plus par motif dans `front/src/lib/notations.ts` :

- `etats` : l'ordre du site (`ETATS`) ;
- `libelles`, `teintes` : `PAR_ETAT` ;
- `seuilsDeMoyenne` et `etatAuDela` : `SEUILS_DE_MOYENNE`, dans l'ordre, puis `ETAT_AU_DELA`.

→ `CoproFirst/Fonctions/Prestataires/Genere/TablesNotations.swift`.
"""

from __future__ import annotations

from generateurs._commun import FONCTIONS, chaine, ecrire_table

SOURCES: list[str] = []


def _notations(ctx) -> tuple[list[str], dict, list[tuple[int | float, str]], str]:
    """La table publiée, vérifiée : une forme inattendue arrête la génération."""
    t = ctx.table("notations")
    etats, par_etat = t.get("etats"), t.get("parEtat")
    seuils, au_dela = t.get("seuilsDeMoyenne"), t.get("etatAuDela")
    lisible = (isinstance(etats, list) and etats and isinstance(par_etat, dict)
               and set(par_etat) == set(etats)
               and all(isinstance(v, dict) and {"libelle", "badge"} <= set(v) for v in par_etat.values())
               and isinstance(seuils, list) and seuils
               and all(isinstance(x, dict) and isinstance(x.get("borne"), (int, float))
                       and x.get("etat") in etats for x in seuils)
               and au_dela in etats)
    if not lisible:
        raise SystemExit(f"❌ notations : forme inattendue ({t!r}) — l'app doit l'apprendre")
    return etats, par_etat, [(x["borne"], x["etat"]) for x in seuils], au_dela


def generer(ctx) -> str:
    etats, table, seuils, au_dela = _notations(ctx)
    corps = (
        "    /// Les états d'un avis, dans l'ordre du site (`ETATS`).\n"
        f"    static let etats = [{', '.join(chaine(e) for e in etats)}]\n"
        "    /// Le libellé de chaque état (`PAR_ETAT`).\n"
        "    static let libelles: [String: String] = [\n"
        + "".join(f"        {chaine(e)}: {chaine(table[e]['libelle'])},\n" for e in etats)
        + "    ]\n"
        "    /// La classe de teinte de chaque état (`PAR_ETAT`).\n"
        "    static let teintes: [String: String] = [\n"
        + "".join(f"        {chaine(e)}: {chaine(table[e]['badge'])},\n" for e in etats)
        + "    ]\n"
        "    /// L'état d'une moyenne (`etatDeMoyenne`) : sous la borne, l'état — dans l'ordre.\n"
        "    static let seuilsDeMoyenne: [(borne: Double, etat: String)] = [\n"
        + "".join(f"        ({borne}, {chaine(etat)}),\n" for borne, etat in seuils)
        + "    ]\n"
        "    /// Au-delà de la dernière borne.\n"
        f"    static let etatAuDela = {chaine(au_dela)}\n"
    )
    ecrire_table(ctx, FONCTIONS / "Prestataires" / "Genere" / "TablesNotations.swift",
                 ctx.provenance_tables("notations"), "TablesNotations",
                 "La notation d'un prestataire, telle que le site l'écrit.", corps)
    return f"{len(etats)} états d'un avis, {len(seuils)} seuils de moyenne"
