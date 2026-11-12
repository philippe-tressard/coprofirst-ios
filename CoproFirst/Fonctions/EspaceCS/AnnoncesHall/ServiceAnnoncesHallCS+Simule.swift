// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// Des affiches inventées, pour les aperçus, les tests et les captures : aucune personne
/// réelle, aucune requête. La liste de départ est le JSON de la route
/// (`FixturesAnnoncesHall`), lu comme le service réel le lit ; les gestes changent la liste
/// de CE service.
extension ServiceSimule: ServiceAnnoncesHallCS {
    func annoncesHall(archivees: Bool, dans installation: Installation) async throws -> [AnnonceHall] {
        try await Task.sleep(for: .milliseconds(350))
        return try modifierSimule(depuis: FixturesAnnoncesHall.affichesLues) { $0 }.filter { $0.archivee == archivees }
    }

    func creerAnnonceHall(_ saisie: SaisieAnnonceHall, dans installation: Installation) async throws -> AnnonceHall {
        try await Task.sleep(for: .milliseconds(500))
        let format = TablesAnnoncesHall.formats.first { $0.code == saisie.format }?.libelle ?? "A5"
        let creee = AnnonceHall(
            id: 100 + Int.random(in: 0..<900), titre: saisie.titre, message: HTMLDeSaisie.depuis(saisie.message),
            assisteIa: false, apercu: saisie.message, lieu: nil,
            formatLabel: format == "Auto" ? "A5" : format, images: [],
            destinataires: saisie.envoyerCS ? ["Lucie Exemple", "Marc Démo"] : [],
            envoyeLe: saisie.envoyerCS ? .now : nil, archivee: false, ticketId: nil, creeLe: .now,
            auteurNom: "Camille Essai", peutArchiver: true, peutRestaurer: false, peutSupprimer: true)
        try modifierSimule(depuis: FixturesAnnoncesHall.affichesLues) { $0.insert(creee, at: 0) }
        return creee
    }

    func archiverAnnonceHall(_ id: Int, archivee: Bool, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
        try modifierSimule(depuis: FixturesAnnoncesHall.affichesLues) { liste in
            guard let i = liste.firstIndex(where: { $0.id == id }) else { return }
            // Ce que le serveur rendrait : rangée à la main, elle se restaure.
            liste[i].archivee = archivee
            liste[i].peutArchiver = !archivee
            liste[i].peutRestaurer = archivee
        }
    }

    func renvoyerAnnonceHall(_ id: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
    }

    func supprimerAnnonceHall(_ id: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
        try modifierSimule(depuis: FixturesAnnoncesHall.affichesLues) { $0.removeAll { $0.id == id } }
    }
}
#endif
