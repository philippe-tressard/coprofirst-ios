// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// « Télémétrie » par le client GÉNÉRÉ : le tableau est typé (`TableauTelemetrie`, contrat
/// 1.16.0).
extension ServiceAPI: ServiceTelemetrie {
    func tableauTelemetrie(
        _ installation: Installation, portee: PorteeTelemetrie, sansGestionnaire: Bool
    ) async throws -> TableauTelemetrie {
        let sortie = try await appeler {
            try await client(installation.adresse).getTelemetryDashboard(
                query: .init(scope: portee.rawValue, gestionnaire: sansGestionnaire ? "sans" : "avec"))
        }
        switch sortie {
        case .ok(let ok): return TableauTelemetrie(try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}
