// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// L'âge relatif (`FormatsDuSite.relatif`, #226) : le formateur nommé d'iOS, en français, à
/// Paris — la carte d'une affaire sur l'iPhone, une alerte sur la montre. Joué sur les deux.
struct FormatsRelatifTests {
    private let maintenant = Date(timeIntervalSince1970: 1_800_000_000)

    /// L'âge d'un instant situé `secondes` avant `maintenant`.
    private func age(_ secondes: TimeInterval) -> String {
        FormatsDuSite.relatif(maintenant.addingTimeInterval(-secondes), maintenant: maintenant)
    }

    @Test func lesUnitesNommees() {
        #expect(age(2 * 3600) == "il y a 2 heures")
        #expect(age(26 * 3600) == "hier")
        #expect(age(3 * 60) == "il y a 3 minutes")
    }

    @Test func uneValeurAbsenteSEcritAuTiret() {
        #expect(FormatsDuSite.relatif(nil) == "—")
    }
}
