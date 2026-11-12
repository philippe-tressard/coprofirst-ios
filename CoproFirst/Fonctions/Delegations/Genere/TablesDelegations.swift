// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.88.1 (commit e13d52923f0429fd082c92e60893e2605a3d6d27), pièce jointe tables-clients.json de la release (pages, statutsDelegation).
// swiftlint:disable line_length

/// Ce que le site écrit des « Délégations aidant » et que le contrat ne sert pas.
enum TablesDelegations {
    /// Le descriptif de la page : ce qu'une délégation permet.
    static let descriptif = "Gestion des accès délégués pour les proches aidants : un proche peut consulter à votre place ce qui vous est adressé, sans pouvoir agir en votre nom ni que cela constitue une procuration d'assemblée générale."
    /// L'état d'une délégation (`STATUTS_DELEGATION`).
    static let statuts: [String: LibelleTeinte] = [
        "en_attente": LibelleTeinte("En attente", "badge-orange"),
        "active": LibelleTeinte("Active", "badge-green"),
        "revoquee": LibelleTeinte("Révoquée", "badge-red"),
        "expiree": LibelleTeinte("Expirée", "badge-gray"),
    ]
}
// swiftlint:enable line_length
