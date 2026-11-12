# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que le CONTRAT borne des notifications et que le client généré n'expose pas :
le nombre d'identifiants qu'accepte UNE requête `POST /notifications/supprimer-selection`
(`maxItems` de `SuppressionNotifications.ids`, dans `openapi.json`, la pièce jointe de la
release) → `CoproFirst/Fonctions/Notifications/Genere/LimitesNotifications.swift`.

swift-openapi-generator ne rend d'un tableau que son type : la borne se perd. L'écran
laissait choisir sans limite, et au-delà le serveur répondait 422 (#118) : la sélection
part désormais en requêtes de cette taille (`EtatNotifications.supprimer`). Écrite à la
main, la borne aurait divergé le jour où le serveur la change ; générée, la concordance
la compare au plancher.
"""

from __future__ import annotations

import json

from generateurs._commun import FONCTIONS, ecrire_table

SOURCES: list[str] = []
PIECES_JOINTES = ["openapi.json"]

SCHEMA = "SuppressionNotifications"
CHAMP = "ids"
ROUTE = "/notifications/supprimer-selection"


def borne(schema: dict) -> int:
    """`maxItems` du corps de la route — et la route doit bien prendre ce corps."""
    try:
        corps = schema["paths"][ROUTE]["post"]["requestBody"]["content"]["application/json"]["schema"]["$ref"]
        maximum = schema["components"]["schemas"][SCHEMA]["properties"][CHAMP]["maxItems"]
    except (KeyError, TypeError) as erreur:
        raise SystemExit(f"❌ {ROUTE} ou {SCHEMA}.{CHAMP}.maxItems introuvable dans openapi.json : {erreur}") from erreur
    if corps != f"#/components/schemas/{SCHEMA}":
        raise SystemExit(f"❌ {ROUTE} ne prend plus {SCHEMA} mais {corps} : la borne est à relire")
    # `bool` est un `int` en Python : un `true` ne passe pas pour une borne.
    if not isinstance(maximum, int) or isinstance(maximum, bool) or maximum < 1:
        raise SystemExit(f"❌ {SCHEMA}.{CHAMP}.maxItems n'est pas un nombre d'au moins 1 : {maximum!r}")
    return maximum


def generer(ctx) -> str:
    try:
        schema = json.loads(ctx.version.piece_jointe("openapi.json"))
    except ValueError as erreur:
        raise SystemExit(f"❌ openapi.json de {ctx.version.etiquette} illisible : {erreur}") from erreur
    maximum = borne(schema)
    corps = f"    /// Le nombre d'identifiants qu'accepte UNE requête POST {ROUTE}\n"
    corps += f"    /// (`maxItems` de `{SCHEMA}.{CHAMP}`) ; au-delà, le serveur répond 422.\n"
    corps += f"    static let selectionParRequete = {maximum}\n"
    ecrire_table(
        ctx, FONCTIONS / "Notifications" / "Genere" / "LimitesNotifications.swift",
        f"pièce jointe openapi.json de la release ({SCHEMA}.{CHAMP}, maxItems)", "LimitesNotifications",
        "Ce que le contrat borne des notifications, et que le client généré n'expose pas (#118).", corps)
    return f"{maximum} identifiants par requête de suppression"
