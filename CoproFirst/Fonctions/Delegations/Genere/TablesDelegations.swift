// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.76.0 (commit 92633e233a414f3d20d189055d71ea62a0b36b41), front/src/lib/pages-roles.ts, src/routes/(app)/delegations/+page.svelte.
// swiftlint:disable line_length

/// Ce que le site écrit des « Délégations aidant » et que le contrat ne sert pas.
enum TablesDelegations {
    /// Le descriptif de la page (`pages-roles.ts`) : ce qu'une délégation permet.
    static let descriptif = "Gestion des accès délégués pour les proches aidants : un proche peut consulter à votre place ce qui vous est adressé, sans pouvoir agir en votre nom ni que cela constitue une procuration d'assemblée générale."
    /// L'état d'une délégation (`parAttribut` de la page du site).
    static let statuts: [String: LibelleTeinte] = [
        "en_attente": LibelleTeinte("En attente", "badge-orange"),
        "active": LibelleTeinte("Active", "badge-green"),
        "revoquee": LibelleTeinte("Révoquée", "badge-red"),
        "expiree": LibelleTeinte("Expirée", "badge-gray"),
    ]
}
// swiftlint:enable line_length
