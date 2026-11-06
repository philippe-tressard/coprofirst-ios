// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.66.0 (commit 14fec7b6ba683cd74161d874e48a47f2d007ff5f), front/src/lib/components/OngletCourriels.svelte, JournalVerdicts.svelte.

/// Ce que le site écrit des Courriels affaires de l'Espace CS et que le contrat ne sert pas.
enum TablesCourriels {
    /// Ce que la relève a fait d'un message (`VERDICTS`), teinté par son ton.
    static let verdicts: [String: LibelleTeinte] = [
        "accepte": LibelleTeinte("Ajouté au fil", "badge-green"),
        "relance": LibelleTeinte("Transmis au conseil", "badge-blue"),
        "refuse": LibelleTeinte("Refusé", "badge-orange"),
        "ignore": LibelleTeinte("Ignoré", "badge-gray"),
    ]
}
