// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce qu'on signale au conseil syndical : `cible_type` et `cible_id` de POST /signalements
/// (`SignalementCreate`). Le type est celui que le site envoie (`signaler('commentaire', id)`).
struct CibleSignalement: Hashable, Sendable {
    let type: String
    let id: Int
}

/// POST /signalements : un motif, au conseil syndical. Deux lecteurs — la Communauté
/// et la fiche d'un sondage (#38) : leurs protocoles en héritent, comme `ServicePerimetres`.
protocol ServiceSignalements: Sendable {
    func signalerAuConseil(_ cible: CibleSignalement, motif: String, dans installation: Installation) async throws
}

extension ServiceAPI: ServiceSignalements {
    func signalerAuConseil(_ cible: CibleSignalement, motif: String, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).postSignalements(
                body: .json(.init(cibleId: cible.id, cibleType: cible.type, motif: motif)))
        }
        switch sortie {
        case .created: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}

#if DEBUG
extension ServiceSimule: ServiceSignalements {
    func signalerAuConseil(_ cible: CibleSignalement, motif: String, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
    }
}
#endif
