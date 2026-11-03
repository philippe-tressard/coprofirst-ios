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

    /// La dernière résidence ouverte : celle que Face ID rouvre au retour.
    var derniere: Installation? { liste.first }

    func faceIDProposee(_ installation: Installation) -> Bool {
        reglages.bool(forKey: "faceid-propose." + installation.hote)
    }

    func noterFaceIDProposee(_ installation: Installation) {
        reglages.set(true, forKey: "faceid-propose." + installation.hote)
    }

    /// Après une déconnexion : Face ID sera reproposé à la prochaine connexion.
    func oublierFaceID(_ installation: Installation) {
        reglages.removeObject(forKey: "faceid-propose." + installation.hote)
    }

    /// Le profil de l'utilisateur dans cette résidence, au dernier passage.
    func noter(_ profil: ProfilResidence, pour installation: Installation) {
        guard let rang = liste.firstIndex(where: { $0.adresse == installation.adresse }) else { return }
        liste[rang].profil = profil
        enregistrer()
    }

    /// « Oublier toutes les résidences » : comme une app neuve.
    func vider() {
        for installation in liste { oublierFaceID(installation) }
        liste = []
        enregistrer()
    }

    /// La plus récente en tête ; une même adresse n'apparaît qu'une fois.
    func retenir(_ installation: Installation) {
        var installation = installation
        // Le profil connu survit à une nouvelle découverte, qui ne le sert pas.
        installation.profil = installation.profil ?? liste.first { $0.adresse == installation.adresse }?.profil
        liste.removeAll { $0.adresse == installation.adresse }
        liste.insert(installation, at: 0)
        enregistrer()
    }

    private func enregistrer() {
        reglages.set(try? JSONEncoder().encode(liste), forKey: Self.cle)
    }
}
