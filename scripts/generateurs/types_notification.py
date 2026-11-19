# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que la cloche montre de chaque TYPE d'alerte : son pictogramme (nom Lucide) et son
libellé pour un lecteur d'écran — la table que coprofirst publie pour ses clients depuis
v3.108.0 (`typesNotification`, `typeNotificationParDefaut` de `constantes-clients.json`,
coprofirst#2802) → `CoproFirst/Fonctions/Notifications/Genere/TypesNotification.swift`,
lue par la ligne d'alerte de la montre (#226) comme par la montre Wear OS.
"""

from __future__ import annotations

from generateurs._commun import FONCTIONS, chaine, ecrire_table

SOURCES: list[str] = []


def _decrit(valeur, quoi: str) -> tuple[str, str]:
    """Un type décrit : `{"pictogramme": …, "libelle": …}`, deux chaînes non vides."""
    if not isinstance(valeur, dict) or set(valeur) != {"pictogramme", "libelle"} or not all(
            isinstance(v, str) and v for v in valeur.values()):
        raise SystemExit(f"❌ {quoi} : forme inattendue ({valeur!r}) — l'app doit l'apprendre")
    return valeur["pictogramme"], valeur["libelle"]


def _ligne(pictogramme: str, libelle: str) -> str:
    return f"TypeNotification(pictogramme: {chaine(pictogramme)}, libelle: {chaine(libelle)})"


def generer(ctx) -> str:
    types = ctx.constante("typesNotification")
    if not isinstance(types, dict) or not types:
        raise SystemExit(f"❌ typesNotification : forme inattendue ({types!r}) — l'app doit l'apprendre")
    decrits = {cle: _decrit(valeur, f"typesNotification[{cle}]") for cle, valeur in types.items()}
    defaut = _decrit(ctx.constante("typeNotificationParDefaut"), "typeNotificationParDefaut")
    table = "".join(f"        {chaine(cle)}: {_ligne(*decrit)},\n" for cle, decrit in sorted(decrits.items()))
    corps = (
        "    /// Par type d'alerte (`NotificationRecue.type`) : son pictogramme et son libellé.\n"
        "    static let parType: [String: TypeNotification] = [\n"
        + table
        + "    ]\n\n"
        "    /// Un type que l'app ne connaît pas encore.\n"
        f"    static let parDefaut = {_ligne(*defaut)}\n"
    )
    ecrire_table(
        ctx, FONCTIONS / "Notifications" / "Genere" / "TypesNotification.swift",
        ctx.provenance_constantes("typesNotification", "typeNotificationParDefaut"), "TypesNotification",
        "Ce que la cloche montre de chaque type d'alerte (coprofirst#2802, #226).", corps)
    return f"{len(decrits)} types d'alerte"
