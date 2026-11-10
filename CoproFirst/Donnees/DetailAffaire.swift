// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Une affaire — ou une actualité, qui EST une affaire de catégorie Actualité —
/// telle que son écran de détail la montre (GET /tickets/{id} et ses évolutions).
struct DetailAffaire: Hashable, Sendable {
    let id: Int
    let numero: String
    let titre: String
    let description: String
    let categorie: String
    var statut: String
    var urgente: Bool
    let creeLe: Date
    let auteur: String?
    /// Le lieu lisible — absent tant que le contrat ne le sert pas (coprofirst#2460).
    let lieu: String?
    /// Les chemins des photos (`/uploads/…`), servis derrière la session.
    let photos: [String]
    var suites: [SuiteAffaire]
    /// Le fil des messages (`TicketMessage`), sous l'Historique — vide sur une actualité.
    var messages: [MessageAffaire] = []
    /// Les gestes que la route accepte de CE lecteur, servis avec l'affaire.
    var droits = DroitsServisAffaire()
    var epingle = false
    var archivee = false
    /// Fusionnée dans une autre : on n'y répond plus (`gesteReponse` du site).
    var fusionnee = false

    var estActualite: Bool { categorie == "actualite" }
    var statutLibelle: String { StatutsAffaire.parCode[statut]?.libelle ?? statut }
}

/// Une entrée de l'Historique : une suite écrite, ou un changement d'état.
struct SuiteAffaire: Identifiable, Hashable, Sendable {
    let id: Int
    let type: String
    let date: Date
    let auteur: String?
    let contenu: String?
    let ancienStatut: String?
    let nouveauStatut: String?
    let photos: [String]

    /// « Ouvert → Chez le syndic », pour une entrée qui change l'état.
    var changementDEtat: String? {
        guard let nouveauStatut else { return nil }
        let nouveau = StatutsAffaire.parCode[nouveauStatut]?.libelle ?? nouveauStatut
        guard let ancienStatut else { return nouveau }
        return "\(StatutsAffaire.parCode[ancienStatut]?.libelle ?? ancienStatut) → \(nouveau)"
    }
}

/// Ce que la route accepte de CE lecteur, tel que le serveur le sert avec l'affaire
/// (`TicketRead.peut_*`, contrat 1.12.0) : lu, jamais recalculé ici (`standards/09` §8).
/// Un champ absent vaut « non ».
struct DroitsServisAffaire: Hashable, Sendable {
    var repondre = false
    var changerEtat = false
    var modifier = false
    var archiver = false
}
