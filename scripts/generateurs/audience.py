# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que le CONTRAT borne d'un lot de mesure d'audience et que le client généré
n'expose pas : le nombre d'évènements d'UN `POST /telemetry/collect` (`maxItems` de
`LotAudience.events`) et la longueur de la page et de l'action qu'elle envoie (`maxLength`
d'`EvenementAudience` — l'app n'envoie pas de `detail`),
dans `openapi.json`, la pièce jointe de la release →
`CoproFirst/Session/Audience/LimitesAudience.swift`.

Le serveur refuse EN BLOC (422) un lot qui les dépasse, vues comprises
(`telemetry_collecte.py` de coprofirst) : l'app vide sa file dès qu'elle atteint le
nombre, et n'y met jamais une page trop longue (`MesureAudience`, coprofirst#2726).
Écrites à la main, ces bornes auraient divergé le jour où le serveur les change ;
générées, la concordance les compare au plancher.
"""

from __future__ import annotations

import json
import pathlib

from generateurs._commun import ecrire_table

SOURCES: list[str] = []
PIECES_JOINTES = ["openapi.json"]

ROUTE = "/telemetry/collect"
LOT = "LotAudience"
EVENEMENT = "EvenementAudience"
CIBLE = pathlib.Path("CoproFirst/Session/Audience/LimitesAudience.swift")


def _nombre(valeur, quoi: str) -> int:
    # `bool` est un `int` en Python : un `true` ne passe pas pour une borne.
    if not isinstance(valeur, int) or isinstance(valeur, bool) or valeur < 1:
        raise SystemExit(f"❌ {quoi} n'est pas un nombre d'au moins 1 : {valeur!r}")
    return valeur


def bornes(schema: dict) -> dict[str, int]:
    """Les bornes du corps de la route — et la route doit bien prendre ce corps."""
    try:
        corps = schema["paths"][ROUTE]["post"]["requestBody"]["content"]["application/json"]["schema"]["$ref"]
        lot = schema["components"]["schemas"][LOT]["properties"]["events"]
        champs = schema["components"]["schemas"][EVENEMENT]["properties"]
        lues = {
            "evenementsParLot": (lot["maxItems"], f"{LOT}.events.maxItems"),
            "page": (champs["page"]["maxLength"], f"{EVENEMENT}.page.maxLength"),
            "action": (champs["action"]["maxLength"], f"{EVENEMENT}.action.maxLength"),
        }
    except (KeyError, TypeError) as erreur:
        raise SystemExit(f"❌ {ROUTE}, {LOT} ou {EVENEMENT} introuvable dans openapi.json : {erreur}") from erreur
    if corps != f"#/components/schemas/{LOT}":
        raise SystemExit(f"❌ {ROUTE} ne prend plus {LOT} mais {corps} : les bornes sont à relire")
    if lot.get("items", {}).get("$ref") != f"#/components/schemas/{EVENEMENT}":
        raise SystemExit(f"❌ {LOT}.events ne porte plus des {EVENEMENT} : les bornes sont à relire")
    return {nom: _nombre(valeur, quoi) for nom, (valeur, quoi) in lues.items()}


def generer(ctx) -> str:
    try:
        schema = json.loads(ctx.version.piece_jointe("openapi.json"))
    except ValueError as erreur:
        raise SystemExit(f"❌ openapi.json de {ctx.version.etiquette} illisible : {erreur}") from erreur
    lues = bornes(schema)
    corps = f"    /// Les évènements qu'accepte UN POST {ROUTE} (`maxItems` de `{LOT}.events`).\n"
    corps += f"    static let evenementsParLot = {lues['evenementsParLot']}\n"
    corps += f"    /// La longueur maximale d'une page (`maxLength` de `{EVENEMENT}.page`).\n"
    corps += f"    static let page = {lues['page']}\n"
    corps += f"    /// La longueur maximale d'une action (`maxLength` de `{EVENEMENT}.action`).\n"
    corps += f"    static let action = {lues['action']}\n"
    ecrire_table(
        ctx, CIBLE, f"pièce jointe openapi.json de la release ({LOT}, {EVENEMENT})", "LimitesAudience",
        "Ce que le contrat borne d'un lot de mesure d'audience — au-delà, le serveur refuse le lot "
        "entier (422).", corps)
    return f"{lues['evenementsParLot']} évènements par lot, page de {lues['page']} caractères au plus"
