// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.76.0 (commit 92633e233a414f3d20d189055d71ea62a0b36b41), front/src/lib/components/BadgeVerdict.svelte, lib/separateurs.ts.

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
    /// Ce qui joint l'acte, la rubrique et la page d'un extrait (`SEPARATEUR.tiret`).
    static let tiret = " —\u{00A0}"
}
