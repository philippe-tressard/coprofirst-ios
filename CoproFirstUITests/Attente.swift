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

    /// Le délai d'une SONDE : l'élément est-il déjà là ? Pour ce qui peut légitimement
    /// manquer — une boucle qui fait défiler jusqu'à lui, un chemin facultatif, une
    /// absence à prouver une fois l'écran posé. Jamais pour affirmer une présence :
    /// une sonde qui échoue n'est pas un défaut de l'app (#147).
    static let sonde: TimeInterval = 2
}

extension XCUIElement {
    /// L'élément existe, au plus tard au plafond commun. Les seules attentes d'existence
    /// des tests sont ces trois-là : `scripts/verifier-depot.sh` refuse tout délai écrit
    /// sur place — 8 s n'ont pas suffi à la feuille des notifications sur un runner
    /// chargé, et `main` en est sorti rouge sans que l'app ait tort (#147).
    func apparait() -> Bool { waitForExistence(timeout: Attente.plafond) }

    /// L'élément n'existe plus, au plus tard au plafond commun.
    func disparait() -> Bool { waitForNonExistence(timeout: Attente.plafond) }

    /// L'élément est-il là dans le délai d'une sonde (`Attente.sonde`) ? Le résultat se
    /// LIT (boucle, chemin facultatif, absence) ; il ne s'affirme pas par `XCTAssertTrue`.
    func sonde() -> Bool { waitForExistence(timeout: Attente.sonde) }

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
