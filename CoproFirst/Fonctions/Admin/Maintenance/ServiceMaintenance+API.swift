// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// « Maintenance » par le client GÉNÉRÉ. La santé des tâches n'est pas typée par le
/// contrat (pas de `response_model`) : elle se relit par `Relecture`, le seul usage admis.
extension ServiceAPI: ServiceMaintenance {
    func santeTaches(_ installation: Installation) async throws -> SanteTaches {
        let sortie = try await appeler { try await client(installation.adresse).getAdminMaintenanceSante() }
        switch sortie {
        case .ok(let ok): return try Relecture.lire(SanteTaches.self, depuis: try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func dernierExport(_ installation: Installation) async throws -> DernierExport {
        let sortie = try await appeler { try await client(installation.adresse).getAdminExportCoproprieteDernier() }
        switch sortie {
        case .ok(let ok): return DernierExport(try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}
