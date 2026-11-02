// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Le parcours v2, contre l'API simulée : aucune requête ne part.
final class ParcoursUITests: XCTestCase {
    @MainActor
    func testDeLAccueilAuFilParLaConnexion() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee"]
        app.launch()

        app.buttons["accueil.entrer"].tap()
        let residence = app.textFields["connexion.residence"]
        XCTAssertTrue(residence.waitForExistence(timeout: 5))
        residence.tap()
        residence.typeText("inconnue.exemple.fr")
        XCTAssertTrue(
            app.staticTexts[
                "Cette adresse répond, mais aucune résidence n'y est installée. "
                    + "Vérifiez-la sur votre fiche d'arrivée."
            ].waitForExistence(timeout: 5),
            "un hôte inconnu (421) se dit en une phrase")

        residence.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + "tilleuls.exemple.fr")
        XCTAssertTrue(app.staticTexts["Résidence Les Tilleuls"].waitForExistence(timeout: 5), "reconnue")

        let email = app.textFields["connexion.email"]
        email.tap()
        email.typeText("resident@exemple.fr\n")
        let motDePasse = app.secureTextFields["connexion.motDePasse"]
        motDePasse.typeText("refuse\n")
        XCTAssertTrue(app.staticTexts["Adresse électronique ou mot de passe incorrect."].waitForExistence(timeout: 5))

        email.tap()
        email.typeText("\n")
        motDePasse.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10) + "secret\n")

        let plusTard = app.buttons["faceid.plusTard"]
        XCTAssertTrue(plusTard.waitForExistence(timeout: 5), "Face ID proposé après la 1ʳᵉ connexion")
        plusTard.tap()
        XCTAssertTrue(app.staticTexts["Fuite d'eau au plafond du parking"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pastille.residence"].exists)
    }

    @MainActor
    func testLaDemoSOuvreDUnToucher() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee"]
        app.launch()

        app.buttons["accueil.demo"].tap()
        let conseil = app.buttons["demo.user-cs"]
        XCTAssertTrue(conseil.waitForExistence(timeout: 5))
        conseil.tap()
        XCTAssertTrue(app.staticTexts["Fuite d'eau au plafond du parking"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLesAffairesSeFiltrentEtSeCherchent() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "affaires"]
        app.launch()

        app.tabBars.buttons["Affaires"].tap()
        XCTAssertTrue(app.staticTexts["Fuite d'eau au plafond du parking"].waitForExistence(timeout: 5))
        let resolues = app.buttons["Résolues"]
        app.buttons["Toutes"].swipeLeft()
        XCTAssertTrue(resolues.waitForExistence(timeout: 3) && resolues.isHittable)
        resolues.tap()
        XCTAssertTrue(app.staticTexts["Portail du garage remis en service"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Fuite d'eau au plafond du parking"].exists)
    }
}
