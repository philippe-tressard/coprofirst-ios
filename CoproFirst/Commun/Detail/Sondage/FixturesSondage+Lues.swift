// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Les fiches de `FixturesSondage`, lues par le branchement de l'iPhone : l'écran de hall
/// compile les réponses seules (#429).
extension FixturesSondage {
    /// Lues comme le client généré les lit, puis par le branchement du service réel.
    static func lues() throws -> [DetailSondage] {
        try Relecture.generee([Components.Schemas.SondageDetail].self, json: fiches)
            .map { DetailSondage($0, moi: moi) }
    }
}
#endif
