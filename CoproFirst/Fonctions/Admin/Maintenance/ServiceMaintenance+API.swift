// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// « Maintenance » par le client GÉNÉRÉ : la santé des tâches se lit par son type
/// (`SanteMaintenance`, contrat 1.16.0, #87).
extension ServiceAPI: ServiceMaintenance {
    func santeTaches(_ installation: Installation) async throws -> SanteTaches {
        let sortie = try await appeler { try await client(installation.adresse).getAdminMaintenanceSante() }
        switch sortie {
        case .ok(let ok): return SanteTaches(try ok.body.json)
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
