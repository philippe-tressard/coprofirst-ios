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
    let statut: String
    let urgente: Bool
    let creeLe: Date
    let auteur: String?
    /// Le lieu lisible — absent tant que le contrat ne le sert pas (coprofirst#2460).
    let lieu: String?
    /// Les chemins des photos (`/uploads/…`), servis derrière la session.
    let photos: [String]
    let suites: [SuiteAffaire]
    /// « Répondre » n'apparaît que si la route l'accepte à coup sûr (`DroitsAffaire`).
    let peutRepondre: Bool

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

/// Qui peut répondre — le sous-ensemble SÛR de `peut_commenter` (`auth/deps.py`) :
/// le conseil syndical, l'auteur et celui pour qui l'affaire a été saisie. Les autres
/// cas (administrateur, comptes externes, actualités) dépendent de règles que l'API
/// ne sert pas encore : l'app n'offre pas un geste que la route pourrait refuser
/// (besoin noté pour coprofirst#2460 : servir `peut_commenter` avec l'affaire).
enum DroitsAffaire {
    static func peutRepondre(moi: Int, roles: [String], auteur: Int?, saisiPour: Int?) -> Bool {
        roles.contains("conseil_syndical") || auteur == moi || saisiPour == moi
    }
}

/// Un sondage, tel que GET /sondages/{id} le sert. Sa réponse n'est pas typée dans le
/// contrat (construite à la main côté serveur, sans `response_model`) : ce miroir
/// la lit (besoin noté pour coprofirst#2460).
struct DetailSondage: Codable, Hashable, Sendable {
    let id: Int
    let question: String
    let description: String?
    let options: [OptionSondage]
    let monVote: Int?
    let cloture: Bool
    let resultatsVisibles: Bool

    enum CodingKeys: String, CodingKey {
        case id, question, description, options, cloture
        case monVote = "mon_vote"
        case resultatsVisibles = "resultats_visibles"
    }

    var totalVotes: Int { options.reduce(0) { $0 + ($1.nbVotes ?? 0) } }
}

struct OptionSondage: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    let libelle: String
    /// Absent quand les résultats sont masqués — jamais 0 : « personne n'a voté » serait faux.
    let nbVotes: Int?

    enum CodingKeys: String, CodingKey {
        case id, libelle
        case nbVotes = "nb_votes"
    }
}
