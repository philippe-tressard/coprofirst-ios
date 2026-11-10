// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Les gestes du bandeau par le client généré, par les deux portes communes
/// (`ajouterEvolution`, `modifierAffaire` — `Session/ServiceAPI+Detail.swift`).
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
}
