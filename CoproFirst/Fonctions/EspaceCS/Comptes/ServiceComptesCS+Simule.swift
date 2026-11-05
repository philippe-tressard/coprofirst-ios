// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// « Comptes & accès » simulé : des comptes et des demandes inventés, aucun nom de
/// personne réelle. Les gestes retirent l'élément de la file, comme le serveur.
extension ServiceSimule: ServiceComptesCS {
    private var fileCS: MagasinSimuleCS<FileComptesSimulee> {
        MagasinSimuleCS.de(self) { FileComptesSimulee() }
    }

    func comptesEnAttente(_ installation: Installation) async throws -> [CompteEnAttente] {
        try await Task.sleep(for: .milliseconds(300))
        return fileCS.valeur.comptes
    }

    func commandesEnAttente(_ installation: Installation) async throws -> [CommandeEnAttente] {
        try await Task.sleep(for: .milliseconds(300))
        return fileCS.valeur.commandes
    }

    func traiterCompte(_ id: Int, valider: Bool, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(350))
        try fileCS.modifier { file in
            guard file.comptes.contains(where: { $0.id == id }) else {
                throw ErreurService.refus(.init(phrase: "Compte déjà traité"))
            }
            file.comptes.removeAll { $0.id == id }
        }
    }

    func accueillir(_ id: Int, _ accueil: AccueilArrivant, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
    }

    func traiterCommande(_ id: Int, accepter codes: [String]?, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(350))
        fileCS.modifier { $0.commandes.removeAll { $0.id == id } }
    }
}

/// La file de travail inventée du conseil.
struct FileComptesSimulee: Sendable {
    var comptes: [CompteEnAttente] = {
        let maintenant = Date.now
        return [
            CompteEnAttente(
                id: 501, prenom: "Camille", nom: "Exemple", statut: "copropriétaire_résident",
                batimentNom: "Bâtiment A", creeLe: maintenant.addingTimeInterval(-2 * 86_400)),
            CompteEnAttente(
                id: 502, prenom: "Dominique", nom: "Fictif", statut: "locataire", batimentNom: "Bâtiment B",
                creeLe: maintenant.addingTimeInterval(-86_400)),
            CompteEnAttente(
                id: 503, prenom: "Alix", nom: "Modèle", statut: "aidant", prenomAide: "Claude", nomAide: "Fictif",
                creeLe: maintenant.addingTimeInterval(-3_600)),
        ]
    }()
    var commandes: [CommandeEnAttente] = [
        CommandeEnAttente(
            id: 71, type: "vigik", quantite: 2, demandeurNom: "Sacha Exemple", lot: "Lot 12 — appartement",
            batiment: "Bâtiment A", creeLe: Date.now.addingTimeInterval(-5 * 86_400)),
        CommandeEnAttente(
            id: 72, type: "telecommande", quantite: 1, demandeurNom: "Morgan Fictif", lot: "Lot 104 — parking",
            batiment: nil, creeLe: Date.now.addingTimeInterval(-86_400)),
    ]
}
