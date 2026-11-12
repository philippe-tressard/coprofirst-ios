// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// #51 — « En savoir plus » montre le contenu de coprofirst.fr (sous `-api-simulee`, la
/// copie embarquée) : ses six rangées, dans l'ordre que l'app accroche aux `id` du site.
final class VitrineUITests: XCTestCase {
    /// `ContenuVitrine.rangees` : le contrat figé avec le site.
    private let rangees = ["demande", "documents", "point-syndic", "badges", "carnet", "communaute"]

    @MainActor
    func testEnSavoirPlusMontreLesRangeesDuSiteDansLOrdreDeLApp() throws {
        let app = LancementCaptures.lancer(ecran: "en-savoir-plus", taille: .parDefaut)
        let titre = element(app, "vitrine.titre")
        XCTAssertTrue(titre.apparait(), "le titre du site")
        XCTAssertFalse(titre.label.isEmpty)
        LancementCaptures.capturer("vitrine-1-haut")
        var bas = -CGFloat.infinity
        for id in rangees {
            let rangee = element(app, "vitrine.rangee.\(id)")
            XCTAssertTrue(rangee.apparait(), "la rangée \(id)")
            XCTAssertFalse(rangee.label.isEmpty, "la rangée \(id) a son texte")
            XCTAssertGreaterThan(rangee.frame.minY, bas, "\(id) vient après la précédente")
            bas = rangee.frame.minY
        }
        app.scrollViews.firstMatch.swipeUp()
        LancementCaptures.capturer("vitrine-2-rangees")
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ identifiant: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifiant).firstMatch
    }
}
