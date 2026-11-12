// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.88.1 (commit e13d52923f0429fd082c92e60893e2605a3d6d27), pièce jointe tables-clients.json de la release (statutsTicket, statutsTicketHistoriques, statutsTicketSansCycle).

/// La pastille de chaque statut d'une affaire (sa classe `badge-*`), comme le site l'écrit.
enum StatutsAffaire {
    static let pastilles: [String: String] = [
        "ouvert": "badge-blue",
        "en_ag": "badge-purple",
        "en_cours": "badge-orange",
        "chez_prestataire": "badge-yellow",
        "résolu": "badge-green",
        "annulé": "badge-gray",
        "fermé": "badge-gray",
        "publie": "badge-blue",
    ]
}
