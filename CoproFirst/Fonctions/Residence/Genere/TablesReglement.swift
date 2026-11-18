// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.117.0 (commit d25fa8df3721cf67b5522648fd22d000b61ca237), front/src/lib/reglement.ts#BADGES_DU_VERDICT (tables-clients.json).

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
