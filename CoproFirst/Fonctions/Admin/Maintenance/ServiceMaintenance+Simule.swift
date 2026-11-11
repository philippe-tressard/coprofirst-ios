// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// « Maintenance » simulée : la santé et le dernier export de `FixturesMaintenance`, lus
/// comme le service réel les lit.
extension ServiceSimule: ServiceMaintenance {
    func santeTaches(_ installation: Installation) async throws -> SanteTaches {
        try await Task.sleep(for: .milliseconds(300))
        return try FixturesMaintenance.santeLue()
    }

    func dernierExport(_ installation: Installation) async throws -> DernierExport {
        try await Task.sleep(for: .milliseconds(250))
        return try FixturesMaintenance.dernierExportLu()
    }
}
#endif
