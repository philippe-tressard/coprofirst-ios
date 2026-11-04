// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Ma résidence et l'Annuaire (#12), sur l'API simulée (un compte du conseil syndical).
final class ResidenceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLesTroisOngletsDeLaResidence() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil"]
        app.launch()

        app.tabBars.buttons["Résidence"].tap()
        XCTAssertTrue(app.staticTexts["AA0-000-000"].waitForExistence(timeout: 5), "la Fiche s'ouvre d'abord")

        app.buttons["Carnet d’entretien"].tap()
        XCTAssertTrue(app.staticTexts["Révision annuelle de la chaudière"].waitForExistence(timeout: 5))

        app.buttons["Règlement"].tap()
        let question = app.staticTexts["Puis-je installer une climatisation sur mon balcon ?"]
        XCTAssertTrue(question.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["reglement.poser"].isEnabled, "question vide : rien à poser")
    }

    @MainActor
    func testLeSyndicDeLaFicheOuvreLAnnuaire() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil"]
        app.launch()

        app.tabBars.buttons["Résidence"].tap()
        let syndic = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Cabinet Exemple Gestion'")).firstMatch
        XCTAssertTrue(syndic.waitForExistence(timeout: 5))
        syndic.tap()
        XCTAssertTrue(app.staticTexts["Gestionnaire de copropriété"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.links.containing(NSPredicate(format: "label CONTAINS '01 00 00 00 01'")).firstMatch.exists)
    }
}
