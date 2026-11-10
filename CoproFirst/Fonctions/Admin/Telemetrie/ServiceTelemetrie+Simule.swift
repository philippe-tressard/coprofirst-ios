// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// « Télémétrie » simulée : un tableau par vue (`FixturesTelemetrie`), lu par `Relecture`
/// comme le service réel. Le filtre n'est appliqué que là où le serveur le propose.
extension ServiceSimule: ServiceTelemetrie {
    func tableauTelemetrie(
        _ installation: Installation, portee: PorteeTelemetrie, sansGestionnaire: Bool
    ) async throws -> TableauTelemetrie {
        try await Task.sleep(for: .milliseconds(350))
        var tableau = try FixturesTelemetrie.tableau(portee)
        if sansGestionnaire, tableau.filtreGestionnaire.propose {
            tableau.filtreGestionnaire.applique = "sans"
            tableau.kpi.vues = tableau.kpi.vues.map { $0 * 9 / 10 }
        }
        return tableau
    }
}
