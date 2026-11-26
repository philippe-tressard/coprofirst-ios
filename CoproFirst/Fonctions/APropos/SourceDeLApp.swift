// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Où obtenir le code de CETTE app, et sous quelle licence : la condition 3 b de la
/// permission App Store (`LICENSES/LicenseRef-CoproFirst-AppStore.txt`), et l'AGPLv3 §13.
/// Écrit une fois pour l'iPhone (`AProposView`) et l'Apple TV (`AProposTVView`, #320) ; le
/// dépôt du serveur, lui, est celui du site (`TextesDuPied.depotSource`).
enum SourceDeLApp {
    static let depot = "https://github.com/philippe-tressard/coprofirst-ios"
    static let libelle = "Code source de l'app"
    static let aide = "Le code de cette app"
    /// La licence, dite comme le pied de page du site.
    static let licence = "\(TextesDuPied.nomPlateforme) est distribué sous la \(TextesDuPied.licenceNom)."

    /// La version de l'app construite (« 1.2 »), lue dans son paquet.
    static func version(_ paquet: Bundle = .main) -> String? {
        paquet.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
