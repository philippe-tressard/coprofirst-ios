// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.117.0 (commit d25fa8df3721cf67b5522648fd22d000b61ca237), pièce jointe openapi.json de la release (SuppressionNotifications.ids, maxItems).

/// Ce que le contrat borne des notifications, et que le client généré n'expose pas (#118).
enum LimitesNotifications {
    /// Le nombre d'identifiants qu'accepte UNE requête POST /notifications/supprimer-selection
    /// (`maxItems` de `SuppressionNotifications.ids`) ; au-delà, le serveur répond 422.
    static let selectionParRequete = 500
}
