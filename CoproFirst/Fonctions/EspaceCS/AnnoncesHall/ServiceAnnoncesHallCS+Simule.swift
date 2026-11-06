// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Des affiches inventées, pour les aperçus, les tests et les captures : aucune personne
/// réelle, aucune requête. Les gestes changent la liste de CE service.
extension ServiceSimule: ServiceAnnoncesHallCS {
    /// Les affiches de CE service simulé (`MagasinSimuleCS`).
    private var affiches: MagasinSimuleCS<[AnnonceHall]> {
        MagasinSimuleCS.de(self) { AffichesSimulees.initiales }
    }

    func annoncesHall(archivees: Bool, dans installation: Installation) async throws -> [AnnonceHall] {
        try await Task.sleep(for: .milliseconds(350))
        return affiches.valeur.filter { $0.archivee == archivees }
    }

    func creerAnnonceHall(_ saisie: SaisieAnnonceHall, dans installation: Installation) async throws -> AnnonceHall {
        try await Task.sleep(for: .milliseconds(500))
        let format = TablesAnnoncesHall.formats.first { $0.code == saisie.format }?.libelle ?? "A5"
        let creee = AnnonceHall(
            id: 100 + Int.random(in: 0..<900), titre: saisie.titre, message: HTMLDeSaisie.depuis(saisie.message),
            assisteIa: false, apercu: saisie.message, perimetreLabel: "Toute la copropriété",
            formatLabel: format == "Auto" ? "A5" : format, images: [],
            destinataires: saisie.envoyerCS ? ["Lucie Exemple", "Marc Démo"] : [],
            envoyeLe: saisie.envoyerCS ? .now : nil, archivee: false, archiveeManuellement: false, ticketId: nil,
            creeLe: .now, auteurNom: "Camille Essai")
        affiches.modifier { $0.insert(creee, at: 0) }
        return creee
    }

    func archiverAnnonceHall(_ id: Int, archivee: Bool, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
        affiches.modifier { liste in
            guard let i = liste.firstIndex(where: { $0.id == id }) else { return }
            liste[i].archivee = archivee
            liste[i].archiveeManuellement = archivee
        }
    }

    func renvoyerAnnonceHall(_ id: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
    }

    func supprimerAnnonceHall(_ id: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
        affiches.modifier { $0.removeAll { $0.id == id } }
    }
}

/// Les affiches de départ d'un service simulé.
private enum AffichesSimulees {
    static let initiales: [AnnonceHall] = [
        AffichesSimulees.affiche(7, "Coupure d'eau jeudi matin", jours: -2) {
            $0.message =
                "<p>L'eau sera coupée <strong>jeudi de 8 h à 12 h</strong> pour le remplacement d'une vanne.</p>"
            $0.apercu = "L'eau sera coupée jeudi de 8 h à 12 h pour le remplacement d'une vanne."
            $0.perimetreLabel = "Bâtiment A"
        },
        AffichesSimulees.affiche(6, "Fête des voisins", jours: -9) {
            $0.message = "<p>Rendez-vous dans le jardin le 6 juin à 19 h. Chacun apporte un plat !</p>"
            $0.apercu = "Rendez-vous dans le jardin le 6 juin à 19 h. Chacun apporte un plat !"
            $0.formatLabel = "A4"
            $0.destinataires = []
            $0.envoyeLe = nil
            $0.assisteIa = true
            $0.ticketId = 31
        },
        AffichesSimulees.affiche(3, "Nettoyage du parking", jours: -60) {
            $0.message = "<p>Merci de libérer vos places le 12 mars au matin.</p>"
            $0.apercu = "Merci de libérer vos places le 12 mars au matin."
            $0.formatLabel = "A6"
            $0.perimetreLabel = "Parking"
            $0.archivee = true
        },
    ]

    /// Une affiche A5 de toute la copropriété, envoyée à deux membres du CS ; `details` la précise.
    private static func affiche(
        _ id: Int, _ titre: String, jours: Double, _ details: (inout AnnonceHall) -> Void
    ) -> AnnonceHall {
        let le = Date.now.addingTimeInterval(jours * 86_400)
        var affiche = AnnonceHall(
            id: id, titre: titre, message: "", assisteIa: false, apercu: "", perimetreLabel: "Toute la copropriété",
            formatLabel: "A5", images: [], destinataires: ["Lucie Exemple", "Marc Démo"], envoyeLe: le,
            archivee: false, archiveeManuellement: false, ticketId: nil, creeLe: le, auteurNom: "Camille Essai")
        details(&affiche)
        return affiche
    }
}
