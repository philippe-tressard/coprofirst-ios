// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Le point d'attente commun des tests du détail d'une affaire (#98) : on attend le
/// détail CHARGÉ, jamais une durée, puis le reste se lit par `.exists`. Le plafond est
/// celui de toutes les attentes (`Attente.plafond`).
extension XCUIApplication {
    /// Le détail de l'affaire `numero` est chargé : son numéro au titre (le squelette
    /// porte « A-0000 ») ET son bandeau, posé dans la même vue — 🔗 est offert à tout
    /// lecteur (`GesteAffaire.offerts`). Après, chaque icône du bandeau, chaque
    /// message et chaque suite se lit par `.exists` : rien n'arrive plus tard.
    @MainActor
    func attendreDetailAffaire(_ numero: String) -> Bool {
        let limite = Date.now.addingTimeInterval(Attente.plafond)
        guard navigationBars[numero].waitForExistence(timeout: Attente.plafond) else { return false }
        return elementAcces("affaire.lien").waitForExistence(timeout: max(1, limite.timeIntervalSinceNow))
    }
}
