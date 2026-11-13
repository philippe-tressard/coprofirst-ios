// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// « Prestataires » simulé : des entreprises inventées, aucun nom de personne, des
/// numéros de la plage réservée à la fiction (01 99 00 …), des adresses `exemple.fr`.
extension ServiceSimule: ServicePrestataires {
    func prestataires(_ installation: Installation, archives: Bool) async throws -> [Prestataire] {
        try await Task.sleep(for: .milliseconds(300))
        return try FixturesPrestataires.lus(archives: archives)
    }

    func contrats(_ installation: Installation, archives: Bool) async throws -> [Contrat] {
        try await Task.sleep(for: .milliseconds(300))
        return archives ? [] : try FixturesPrestataires.contratsLus()
    }

    func avis(_ installation: Installation) async throws -> [AvisPrestataire] {
        try await Task.sleep(for: .milliseconds(200))
        return PrestatairesSimules.avis
    }

    func equipements(_ installation: Installation) async throws -> [Equipement] {
        try await Task.sleep(for: .milliseconds(150))
        return PrestatairesSimules.equipements
    }

    func documents(contrat: Int, dans installation: Installation) async throws -> [DocumentContrat] {
        try await Task.sleep(for: .milliseconds(200))
        guard contrat == 1 else { return [] }
        return [DocumentContrat(id: 7, titre: "Contrat d'entretien signé", fichierNom: "contrat-ascenseur.pdf")]
    }

    func compteurs(_ installation: Installation) async throws -> [Compteur] {
        try await Task.sleep(for: .milliseconds(200))
        return [
            Compteur(id: 1, typeCompteur: "eau_generale", libelle: "Eau générale", ordre: 0, prestataireId: 3),
            Compteur(id: 2, typeCompteur: "edf_parking", libelle: "EDF Parking", ordre: 1, prestataireId: nil),
        ]
    }

    func releves(_ typeCompteur: String, dans installation: Installation) async throws -> [Releve] {
        try await Task.sleep(for: .milliseconds(300))
        guard typeCompteur == "eau_generale" else { return [] }
        return [
            Releve(id: 4, dateReleve: "2026-10-02", index: 47_047, note: nil, photoUrl: "/uploads/releves/4.jpg"),
            Releve(id: 3, dateReleve: "2026-04-01", index: 46_112, note: "Changement compteur", photoUrl: nil),
            Releve(id: 2, dateReleve: "2025-10-01", index: 45_380, note: nil, photoUrl: nil),
            Releve(id: 1, dateReleve: "2025-04-03", index: nil, note: "Compteur inaccessible", photoUrl: nil),
        ]
    }
}

/// Les avis et équipements simulés (les fiches et les contrats : `FixturesPrestataires`).
enum PrestatairesSimules {
    static let avis: [AvisPrestataire] = [
        AvisPrestataire(
            id: 1, prestataireId: 1, note: 4, commentaire: "Intervention rapide lors de la dernière panne.",
            auteurNom: "Conseil syndical", creeLe: Date(timeIntervalSince1970: 1_790_000_000)),
        AvisPrestataire(
            id: 2, prestataireId: 1, note: 5, commentaire: nil, auteurNom: "Conseil syndical",
            creeLe: Date(timeIntervalSince1970: 1_780_000_000)),
    ]

    static let equipements: [Equipement] = [
        Equipement(code: "ascenseur", libelle: "Ascenseurs", ordre: 0),
        Equipement(code: "incendie", libelle: "Sécurité incendie", ordre: 1),
        Equipement(code: "eau", libelle: "Eau", ordre: 2),
        Equipement(code: "facade", libelle: "Façades", ordre: 3),
    ]
}
#endif
