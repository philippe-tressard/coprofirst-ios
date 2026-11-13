// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Les gestes du bandeau par le client généré, par les deux portes communes
/// (`ajouterEvolution`, `modifierAffaire` — `Session/ServiceAPI+Detail.swift`) ; ceux
/// d'une entrée de l'Historique, par les deux routes d'une évolution (PATCH, DELETE).
extension ServiceAPI: ServiceGestesAffaire {
    func ajouterSuite(_ suite: SaisieSuite, a affaire: Int, dans installation: Installation) async throws {
        var nouveau: Components.Schemas.StatutTicket?
        if suite.changeEtat {
            guard let statut = Components.Schemas.StatutTicket(rawValue: suite.statut) else {
                throw ErreurService.inattendue(422)
            }
            nouveau = statut
        }
        let contenu = suite.texte.isEmpty ? nil : TexteDuSite.html(saisi: suite.texte)
        try await ajouterEvolution(
            .init(contenu: contenu, nouveauStatut: nouveau, _type: suite.type), a: affaire, dans: installation)
    }

    func enregistrer(_ edition: EditionAffaire, de affaire: Int, dans installation: Installation) async throws {
        let corps = Components.Schemas.TicketUpdate(
            categorie: edition.categorie, description: edition.descriptionHTML,
            perimetreCible: edition.perimetres, titre: edition.titre, urgente: edition.urgente)
        try await modifierAffaire(affaire, corps, dans: installation)
    }

    func regler(
        _ option: OptionAffaire, active: Bool, de affaire: Int, dans installation: Installation
    ) async throws {
        let corps: Components.Schemas.TicketUpdate =
            option.cle == "epingle" ? .init(epingle: active) : .init(urgente: active)
        try await modifierAffaire(affaire, corps, dans: installation)
    }

    func archiverAffaire(_ affaire: Int, dans installation: Installation) async throws {
        try await modifierAffaire(affaire, .init(archiveManuel: true), dans: installation)
    }

    func corrigerSuite(
        _ correction: CorrectionSuite, _ suite: Int, de affaire: Int, dans installation: Installation
    ) async throws {
        let corps = try Self.corpsCorrection(correction)
        let sortie = try await appeler {
            try await client(installation.adresse).patchTicketsTicketIdEvolutionsEvolId(
                path: .init(ticketId: affaire, evolId: suite), body: .json(corps))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func supprimerSuite(_ suite: Int, de affaire: Int, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).deleteTicketsTicketIdEvolutionsEvolId(
                path: .init(ticketId: affaire, evolId: suite))
        }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    /// Le corps de « Modifier la suite » (`chargeCorrection` du site) : le texte s'il a
    /// changé, le Suivi s'il a changé — `type`, et l'état que l'entrée donne. Le reste de
    /// l'entrée (pièces jointes, lieu) ne part pas : le serveur n'y touche pas.
    static func corpsCorrection(_ correction: CorrectionSuite) throws -> Components.Schemas.TicketEvolutionUpdate {
        var nouveau: Components.Schemas.StatutTicket?
        if let statut = correction.suivi?.statut {
            guard let lu = Components.Schemas.StatutTicket(rawValue: statut) else {
                throw ErreurService.inattendue(422)
            }
            nouveau = lu
        }
        return .init(contenu: correction.contenuHTML, nouveauStatut: nouveau, _type: correction.suivi?.type)
    }
}
