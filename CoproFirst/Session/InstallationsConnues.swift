// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Observation

/// Les résidences déjà ouvertes sur cet appareil : l'adresse et le nom, et le courriel
/// de la dernière connexion réussie, pour pré-remplir la suivante — sur l'appareil
/// seul, jamais envoyé ailleurs, effacé par « Oublier toutes les résidences ».
/// Pas d'annuaire : une résidence n'apparaît ici que si l'utilisateur l'a saisie.
///
/// Les réglages (`UserDefaults`) ne gardent que la résidence — son adresse, son nom, sa
/// présentation. Ce qui dit QUI est l'utilisateur (profil, courriel) va au coffre du
/// compte, le Trousseau (#84).
@MainActor @Observable
final class InstallationsConnues {
    private(set) var liste: [Installation]
    private let reglages: UserDefaults
    private let coffre: any CoffreDuCompte
    private static let cle = "installations-connues"
    private static let prefixeIdentifiant = "identifiant."
    private static let prefixeProfil = "profil."

    init(reglages: UserDefaults = .standard, coffre: any CoffreDuCompte = CoffreTrousseau()) {
        self.reglages = reglages
        self.coffre = coffre
        let donnees = reglages.data(forKey: Self.cle) ?? Data()
        liste = (try? JSONDecoder().decode([Installation].self, from: donnees)) ?? []
        migrerVersLeCoffre()
        for rang in liste.indices {
            liste[rang].profil = (coffre.lire(Self.prefixeProfil + liste[rang].hote))
                .flatMap { try? JSONDecoder().decode(ProfilResidence.self, from: $0) }
        }
    }

    /// Migration douce (#84) : un profil ou un courriel qu'une version antérieure a
    /// écrit dans les réglages passe au coffre, puis s'efface des réglages.
    private func migrerVersLeCoffre() {
        var reecrire = false
        for installation in liste {
            guard let profil = installation.profil else { continue }
            let cle = Self.prefixeProfil + installation.hote
            if coffre.lire(cle) == nil, let donnees = try? JSONEncoder().encode(profil) {
                coffre.ranger(donnees, cle)
            }
            reecrire = true
        }
        for cle in reglages.dictionaryRepresentation().keys where cle.hasPrefix(Self.prefixeIdentifiant) {
            if let email = reglages.string(forKey: cle), coffre.lire(cle) == nil {
                coffre.ranger(Data(email.utf8), cle)
            }
            reglages.removeObject(forKey: cle)
        }
        if reecrire { enregistrer() }
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

    /// Le courriel de la dernière connexion réussie à cette résidence.
    func identifiant(_ installation: Installation) -> String? {
        coffre.lire(Self.prefixeIdentifiant + installation.hote).flatMap { String(data: $0, encoding: .utf8) }
    }

    func retenirIdentifiant(_ email: String, pour installation: Installation) {
        coffre.ranger(Data(email.utf8), Self.prefixeIdentifiant + installation.hote)
    }

    /// Le profil de l'utilisateur dans cette résidence, au dernier passage.
    func noter(_ profil: ProfilResidence, pour installation: Installation) {
        guard let rang = liste.firstIndex(where: { $0.adresse == installation.adresse }) else { return }
        liste[rang].profil = profil
        if let donnees = try? JSONEncoder().encode(profil) {
            coffre.ranger(donnees, Self.prefixeProfil + installation.hote)
        }
    }

    /// « Oublier toutes les résidences » : comme une app neuve.
    func vider() {
        for installation in liste {
            oublierFaceID(installation)
            coffre.effacer(Self.prefixeIdentifiant + installation.hote)
            coffre.effacer(Self.prefixeProfil + installation.hote)
        }
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

    /// Les résidences, sans le profil : il est au coffre.
    private func enregistrer() {
        let residences = liste.map { installation -> Installation in
            var installation = installation
            installation.profil = nil
            return installation
        }
        reglages.set(try? JSONEncoder().encode(residences), forKey: Self.cle)
    }
}
