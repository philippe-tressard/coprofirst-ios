// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Le point d'attente commun des tests d'interface (#98, #123) : on attend un ÉTAT,
/// jamais une durée.
enum Attente {
    /// Le plafond, large exprès. Sur un runner chargé, une requête d'accessibilité met
    /// 1 à 2 s et une seule évaluation peut manger un délai de 3 s (#123) ; le détail
    /// d'une affaire y est arrivé jusqu'à 12 s après le toucher (#98). L'attente rend
    /// la main dès que l'état est là : un plafond large ne ralentit pas un test vert,
    /// il ne coûte qu'à un test rouge.
    static let plafond: TimeInterval = 30
}

extension XCUIElement {
    /// L'élément est dans l'état `condition` — un format de `NSPredicate`, par exemple
    /// « hasKeyboardFocus == true » — au plus tard au plafond commun. La seule attente
    /// par prédicat des tests : `scripts/verifier-depot.sh` refuse les autres, dont
    /// chacune portait son propre délai.
    @MainActor
    func attendre(_ condition: String) -> Bool {
        let etat = XCTNSPredicateExpectation(predicate: NSPredicate(format: condition), object: self)
        return XCTWaiter().wait(for: [etat], timeout: Attente.plafond) == .completed
    }
}
