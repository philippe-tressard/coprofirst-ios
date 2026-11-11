// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Le point d'attente commun des tests du détail d'une affaire (#98) : on attend le
/// détail CHARGÉ, jamais une durée, puis le reste se lit par `.exists`.
extension XCUIApplication {
    /// Le plafond : sur le runner de la CI, le bandeau est arrivé jusqu'à 12 s après le
    /// toucher (#98) — l'attente rend la main dès qu'il est là.
    static let plafondDetailAffaire: TimeInterval = 30

    /// Le détail de l'affaire `numero` est chargé : son numéro au titre (le squelette
    /// porte « A-0000 ») ET son bandeau, posé dans la même vue — 🔗 est offert à tout
    /// lecteur (`GesteAffaire.offerts`). Après, chaque icône du bandeau, chaque
    /// message et chaque suite se lit par `.exists` : rien n'arrive plus tard.
    @MainActor
    func attendreDetailAffaire(_ numero: String) -> Bool {
        let limite = Date.now.addingTimeInterval(Self.plafondDetailAffaire)
        guard navigationBars[numero].waitForExistence(timeout: Self.plafondDetailAffaire) else { return false }
        return elementAcces("affaire.lien").waitForExistence(timeout: max(1, limite.timeIntervalSinceNow))
    }
}
