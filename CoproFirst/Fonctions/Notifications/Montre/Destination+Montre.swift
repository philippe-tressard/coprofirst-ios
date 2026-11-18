// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

extension Destination {
    /// La cloche que la montre propose de continuer (`ClocheSurLiPhone`, Handoff) : l'adresse
    /// annoncée, normalisée comme celle d'un lien (`LienUniversel`), et l'écran des alertes.
    static func clocheDeLaMontre(_ userInfo: [AnyHashable: Any]?) -> Destination? {
        guard let adresse = ClocheSurLiPhone.adresse(userInfo), let lien = LienUniversel.destination(adresse)
        else { return nil }
        return Destination(adresse: lien.adresse, ecran: .notifications)
    }
}
