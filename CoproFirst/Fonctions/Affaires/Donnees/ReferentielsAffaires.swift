// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que la résidence SERT des affaires (`GET /tickets/referentiels`, contrat 1.14.0) :
/// les colonnes du Kanban, les états et les catégories — lus, jamais recalculés ici
/// (`standards/09` §8, #83). La colonne d'UNE affaire se lit sur elle (`colonne_kanban`).
struct ReferentielsAffaires: Hashable, Sendable {
    /// Un état d'une affaire : sa colonne au Kanban (`nil` hors tableau), et s'il la clôt.
    struct Statut: Hashable, Sendable {
        let code: String
        let libelle: String
        let clos: Bool
        let colonne: String?
    }

    /// Une catégorie : ce que le pied d'une carte en montre.
    struct Categorie: Hashable, Sendable {
        let code: String
        let libelle: String
        let emoji: String
    }

    /// Les colonnes, dans l'ordre servi — ces colonnes SONT le workflow.
    let colonnes: [ColonneKanban]
    let statuts: [Statut]
    let categories: [Categorie]

    /// L'état qu'une colonne pose quand on y glisse une carte : le premier, dans l'ordre
    /// servi, que le serveur range dans cette colonne. `nil` : rien n'y mène.
    func statut(pourColonne colonne: String) -> Statut? { statuts.first { $0.colonne == colonne } }

    func categorie(_ code: String) -> Categorie? { categories.first { $0.code == code } }
}

extension ReferentielsAffaires {
    init(lu: Components.Schemas.ReferentielsAffaires) {
        self.init(
            colonnes: lu.colonnesKanban.map {
                ColonneKanban(id: $0.code, libelle: $0.libelle, libelleCourt: $0.libelleCourt)
            },
            statuts: lu.statuts.map {
                Statut(code: $0.code, libelle: $0.libelle, clos: $0.clos, colonne: $0.colonneKanban)
            },
            categories: lu.categories.map { Categorie(code: $0.code, libelle: $0.libelle, emoji: $0.emoji) })
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

extension ServiceSimule {
    func referentiels(_ installation: Installation) async throws -> ReferentielsAffaires {
        try FixturesReferentielsAffaires.lus()
    }
}
