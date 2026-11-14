// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// « Télémétrie » par le client GÉNÉRÉ : le tableau est typé (`TableauTelemetrie`, contrat
/// 1.16.0). Le corps se garde (`CorpsServi.garder`) : la répartition par canal se sert
/// au-dessus du plancher (contrat 1.31.0, coprofirst#2726), et le type généré la jetterait.
extension ServiceAPI: ServiceTelemetrie {
    func tableauTelemetrie(
        _ installation: Installation, portee: PorteeTelemetrie, sansGestionnaire: Bool
    ) async throws -> TableauTelemetrie {
        let (sortie, corps) = try await appeler {
            try await CorpsServi.garder {
                try await client(installation.adresse).getTelemetryDashboard(
                    query: .init(scope: portee.rawValue, gestionnaire: sansGestionnaire ? "sans" : "avec"))
            }
        }
        switch sortie {
        case .ok(let ok): return TableauTelemetrie(try ok.body.json, corps: corps)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}
