// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// « Comptes & accès » simulé : des comptes et des demandes inventés, aucun nom de
/// personne réelle, lus du JSON de leurs routes (`FixturesComptesCS`) comme le service réel
/// les lit. Les gestes retirent l'élément de la file, comme le serveur.
extension ServiceSimule: ServiceComptesCS {
    func comptesEnAttente(_ installation: Installation) async throws -> [CompteEnAttente] {
        try await Task.sleep(for: .milliseconds(300))
        return try modifierSimule(depuis: FixturesComptesCS.comptesLus) { $0 }
    }

    func commandesEnAttente(_ installation: Installation) async throws -> [CommandeEnAttente] {
        try await Task.sleep(for: .milliseconds(300))
        return try modifierSimule(depuis: FixturesComptesCS.commandesLues) { $0 }
    }

    func traiterCompte(_ id: Int, valider: Bool, dans installation: Installation) async throws -> PhraseAvis? {
        try await Task.sleep(for: .milliseconds(350))
        try modifierSimule(depuis: FixturesComptesCS.comptesLus) { comptes in
            guard comptes.contains(where: { $0.id == id }) else {
                throw ErreurService.refus(.init(phrase: "Compte déjà traité"))
            }
            comptes.removeAll { $0.id == id }
        }
        // Un refus n'a pas d'annonce (`null`), comme le serveur.
        return valider ? try FixturesComptesCS.annonceDeValidation(id) : nil
    }

    func accueillir(_ id: Int, _ accueil: AccueilArrivant, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
    }

    func traiterCommande(_ id: Int, accepter codes: [String]?, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(350))
        try modifierSimule(depuis: FixturesComptesCS.commandesLues) { $0.removeAll { $0.id == id } }
    }
}
