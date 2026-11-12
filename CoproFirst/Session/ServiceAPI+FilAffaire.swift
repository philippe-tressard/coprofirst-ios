// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Les rubriques du fil d'une affaire que GET /tickets/{id} ne porte pas (#178) — par le
/// client généré. Aucune n'empêche de lire l'affaire : un échec se dit dans sa rubrique.
extension ServiceAPI {
    /// GET /points-conseil/affaires/{id} : les comptes rendus validés que ce lecteur peut
    /// lire, le plus récent en tête (`ComptesRendusAffaire` du site) ; `nil` si illisibles.
    func comptesRendus(_ id: Int, client: Client) async -> [CompteRenduAffaire]? {
        let sortie = try? await appeler {
            try await client.getPointsConseilAffairesTicketId(path: .init(ticketId: id))
        }
        guard case .ok(let ok)? = sortie, let lus = try? ok.body.json else { return nil }
        return lus.map(CompteRenduAffaire.init).sorted { $0.debut > $1.debut }
    }

    /// GET /tickets/{id}/synthese : la synthèse servie (`SyntheseFil` du site) ; `nil` sans
    /// synthèse, ou illisible — la rubrique se tait alors, comme celle du site.
    func synthese(_ id: Int, client: Client) async -> SyntheseAffaire? {
        let sortie = try? await appeler {
            try await client.getTicketsTicketIdSynthese(path: .init(ticketId: id))
        }
        guard case .ok(let ok)? = sortie, let etat = try? ok.body.json else { return nil }
        return SyntheseAffaire(etat)
    }
}
