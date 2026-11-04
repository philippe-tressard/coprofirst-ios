// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Le journal des courriels par le client GÉNÉRÉ : la réponse est typée.
extension ServiceAPI: ServiceCourriels {
    func journalCourriels(_ installation: Installation) async throws -> JournalCourriels {
        switch try await appeler({ try await client(installation.adresse).getCourrielsAffaires() }) {
        case .ok(let ok):
            let lu = try ok.body.json
            return JournalCourriels(
                limite: lu.limite,
                messages: lu.messages.map {
                    CourrielReleve(
                        id: $0.id, releveLe: $0.releveLe, envoyeLe: $0.envoyeLe, expediteur: $0.expediteur,
                        objet: $0.objet, decision: $0.decision, motif: $0.motif, ticketId: $0.ticketId,
                        affaire: $0.affaire)
                })
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}
