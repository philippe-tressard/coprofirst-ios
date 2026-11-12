// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que la résidence SERT des affaires (`GET /tickets/referentiels`, contrat 1.14.0) :
/// les colonnes du Kanban, les états et les catégories — lus, jamais recalculés ici
/// (`standards/09` §8, #83). La colonne d'UNE affaire se lit sur elle (`colonne_kanban`).
struct ReferentielsAffaires: Hashable, Sendable {
    /// Un état d'une affaire : sa colonne au Kanban (`nil` hors tableau), s'il la clôt, et
    /// s'il s'offre dans une Suite (`proposable` : le cycle d'une affaire — `fermé`,
    /// historique, et `publie`, d'une actualité, s'affichent sans jamais se proposer, #105).
    struct Statut: Hashable, Sendable {
        let code: String
        let libelle: String
        let clos: Bool
        let colonne: String?
        var proposable = false
    }

    /// Une catégorie, telle que la grille de saisie la montre, avec ce que CE compte peut
    /// poser (`permise`, la règle même qui refuse la création, #105) et les sections que la
    /// saisie Essentielle montre pour elle (#69).
    struct Categorie: Hashable, Sendable {
        let code: String
        let libelle: String
        let emoji: String
        var description = ""
        var carnet = false
        /// Réservée au conseil syndical : le serveur la refuse à un autre compte (403).
        var reservee = false
        var permise = false
        var enTete = false
        var sectionsEssentielles: [String] = []
    }

    /// Les colonnes, dans l'ordre servi — ces colonnes SONT le workflow.
    let colonnes: [ColonneKanban]
    let statuts: [Statut]
    let categories: [Categorie]

    /// L'état qu'une colonne pose quand on y glisse une carte : le premier, dans l'ordre
    /// servi, que le serveur range dans cette colonne. `nil` : rien n'y mène.
    func statut(pourColonne colonne: String) -> Statut? { statuts.first { $0.colonne == colonne } }

    func categorie(_ code: String) -> Categorie? { categories.first { $0.code == code } }

    /// Les états qu'une Suite offre, dans l'ordre servi (`etatsDeLaSuite` du site).
    var proposables: [Statut] { statuts.filter(\.proposable) }

    /// Les catégories que CE compte peut poser, dans l'ordre servi, « Actualité » en tête
    /// (`en_tete`) — ce que la grille de saisie propose.
    var permises: [CategorieAffaire] {
        let permises = categories.filter(\.permise).map {
            CategorieAffaire(
                code: $0.code, libelle: $0.libelle, emoji: $0.emoji, description: $0.description, carnet: $0.carnet,
                enTete: $0.enTete)
        }
        return permises.filter(\.enTete) + permises.filter { !$0.enTete }
    }

    /// Les catégories que « Modifier » propose pour une affaire de cette catégorie : les
    /// permises, si la sienne en est. Une catégorie que ce compte ne pourrait pas reposer ne
    /// se propose pas — elle resterait cochée sans se voir ; une actualité ne se convertit
    /// donc qu'à qui le serveur la permet.
    func permises(enModifiant categorie: String) -> [CategorieAffaire] {
        let permises = permises
        return permises.contains { $0.code == categorie } ? permises : []
    }

    /// Ce compte pose-t-il ce que le serveur réserve au conseil syndical ? Lu des catégories
    /// servies (`reservee` ET `permise`, la règle même qui refuse la création) — jamais
    /// déduit du profil (#105).
    var poseLesReservees: Bool { categories.contains { $0.reservee && $0.permise } }

    /// Avant toute lecture (le squelette d'un écran) : rien de servi, donc rien d'offert.
    static let vides = ReferentielsAffaires(colonnes: [], statuts: [], categories: [])
}

extension ReferentielsAffaires {
    init(lu: Components.Schemas.ReferentielsAffaires) {
        self.init(
            colonnes: lu.colonnesKanban.map {
                ColonneKanban(id: $0.code, libelle: $0.libelle, libelleCourt: $0.libelleCourt)
            },
            statuts: lu.statuts.map {
                Statut(
                    code: $0.code, libelle: $0.libelle, clos: $0.clos, colonne: $0.colonneKanban,
                    proposable: $0.proposable)
            },
            categories: lu.categories.map {
                Categorie(
                    code: $0.code, libelle: $0.libelle, emoji: $0.emoji, description: $0.description,
                    carnet: $0.carnet, reservee: $0.reservee, permise: $0.permise, enTete: $0.enTete,
                    sectionsEssentielles: $0.sectionsEssentielles)
            })
    }
}

extension ServiceAPI {
    /// GET /tickets/referentiels, par le client GÉNÉRÉ.
    func referentiels(_ installation: Installation) async throws -> ReferentielsAffaires {
        let sortie = try await appeler { try await client(installation.adresse).getTicketsReferentiels() }
        switch sortie {
        case .ok(let ok): return ReferentielsAffaires(lu: try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}
