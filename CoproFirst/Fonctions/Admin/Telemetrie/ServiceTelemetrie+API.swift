// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// « Télémétrie » par le client GÉNÉRÉ. Le tableau n'est pas typé par le contrat (pas de
/// `response_model`) : il se relit par `Relecture`, le seul usage admis.
extension ServiceAPI: ServiceTelemetrie {
    func tableauTelemetrie(
        _ installation: Installation, portee: PorteeTelemetrie, sansGestionnaire: Bool
    ) async throws -> TableauTelemetrie {
        let sortie = try await appeler {
            try await client(installation.adresse).getTelemetryDashboard(
                query: .init(scope: portee.rawValue, gestionnaire: sansGestionnaire ? "sans" : "avec"))
        }
        switch sortie {
        case .ok(let ok): return try Relecture.lire(TableauTelemetrie.self, depuis: try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}
