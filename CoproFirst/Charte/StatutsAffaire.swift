// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.76.0 (commit 92633e233a414f3d20d189055d71ea62a0b36b41), front/src/lib/tickets.ts (STATUTS_TICKET et compléments).

/// Le libellé et la pastille de chaque statut d'une affaire, comme le site les écrit.
enum StatutsAffaire {
    static let parCode: [String: (libelle: String, pastille: String)] = [
        "ouvert": ("Ouvert", "badge-blue"),
        "en_ag": ("À l’AG", "badge-purple"),
        "en_cours": ("Chez le syndic", "badge-orange"),
        "chez_prestataire": ("Chez le prestataire", "badge-yellow"),
        "résolu": ("Résolu", "badge-green"),
        "annulé": ("Annulé", "badge-gray"),
        "fermé": ("Fermé", "badge-gray"),
        "publie": ("Publiée", "badge-blue"),
    ]
}
