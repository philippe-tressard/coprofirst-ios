// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Observation

/// Les résidences déjà ouvertes sur cet appareil : l'adresse et le nom, rien d'autre.
/// Pas d'annuaire : une résidence n'apparaît ici que si l'utilisateur l'a saisie.
@MainActor @Observable
final class InstallationsConnues {
    private(set) var liste: [Installation]
    private let reglages: UserDefaults
    private static let cle = "installations-connues"

    init(reglages: UserDefaults = .standard) {
        self.reglages = reglages
        let donnees = reglages.data(forKey: Self.cle) ?? Data()
        liste = (try? JSONDecoder().decode([Installation].self, from: donnees)) ?? []
    }

    /// La plus récente en tête ; une même adresse n'apparaît qu'une fois.
    func retenir(_ installation: Installation) {
        liste.removeAll { $0.adresse == installation.adresse }
        liste.insert(installation, at: 0)
        reglages.set(try? JSONEncoder().encode(liste), forKey: Self.cle)
    }
}
