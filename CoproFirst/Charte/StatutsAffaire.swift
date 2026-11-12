// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.89.0 (commit 10b85f3356d538254bfdca6f54270063c9008d4b), front/src/lib/tickets.ts#STATUTS_TICKET, front/src/lib/tickets.ts#STATUTS_TICKET_HISTORIQUES, front/src/lib/tickets.ts#STATUTS_TICKET_SANS_CYCLE (tables-clients.json).

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
