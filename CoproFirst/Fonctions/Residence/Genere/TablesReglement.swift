// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.126.10 (commit 803696b615c922d3c0b93f69e2c81c6fa44c3e4c), front/src/lib/reglement.ts#BADGES_DU_VERDICT (tables-clients.json).

/// Ce que le site écrit de l'avis sur le règlement et que le contrat ne sert pas.
enum TablesReglement {
    /// La classe de la capsule du verdict, pour chaque ton servi (`BadgeVerdict.svelte`).
    static let badgesDuVerdict: [String: String] = [
        "succes": "badge-green",
        "danger": "badge-red",
        "alerte": "badge-orange",
        "neutre": "badge-gray",
    ]
    /// Un ton absent ou inconnu : le site le lit incertain.
    static let badgeDuVerdictInconnu = "badge-yellow"
}
