// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Les réponses de `FixturesCommunaute`, lues par les types générés puis par le MÊME
/// branchement que le service réel.
extension FixturesCommunaute {
    static func ideesLues() throws -> [Idee] {
        try Relecture.generee([Components.Schemas.IdeeRead].self, json: idees).map(Idee.init)
    }

    static func annoncesLues() throws -> [Annonce] {
        try Relecture.generee([Components.Schemas.AnnonceRead].self, json: annonces).map(Annonce.init)
    }
}
#endif
