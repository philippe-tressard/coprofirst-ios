// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Le parcours d'entrée complet, contre l'API simulée : aucune requête ne part.
final class ParcoursUITests: XCTestCase {
    @MainActor
    func testDeLaPresentationAuxAffaires() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee"]
        app.launch()

        app.buttons["presentation.entrer"].tap()

        let adresse = app.textFields["residence.adresse"]
        XCTAssertTrue(adresse.waitForExistence(timeout: 5))
        adresse.tap()
        adresse.typeText("inconnue.exemple.fr")
        app.buttons["residence.continuer"].tap()
        XCTAssertTrue(
            app.staticTexts[
                "Cette adresse répond, mais aucune résidence n'y est installée. "
                    + "Vérifiez-la sur votre fiche d'arrivée."
            ].waitForExistence(timeout: 5),
            "un hôte inconnu (421) se dit en une phrase")

        adresse.tap()
        adresse.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + "tilleuls.exemple.fr")
        app.buttons["residence.continuer"].tap()

        let email = app.textFields["connexion.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Résidence Les Tilleuls"].exists)
        email.tap()
        // Retour : le focus passe au mot de passe (focus enchaîné de l'écran).
        email.typeText("resident@exemple.fr\n")
        let motDePasse = app.secureTextFields["connexion.motDePasse"]
        XCTAssertTrue(motDePasse.waitForExistence(timeout: 3))
        motDePasse.typeText("refuse")
        app.buttons["connexion.valider"].tap()
        XCTAssertTrue(app.staticTexts["Adresse électronique ou mot de passe incorrect."].waitForExistence(timeout: 5))

        email.tap()
        email.typeText("\n")
        motDePasse.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10) + "secret")
        app.buttons["connexion.valider"].tap()

        XCTAssertTrue(app.navigationBars["Affaires"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Fuite d'eau au plafond du parking"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Nouvelle affaire"].exists)
    }

    @MainActor
    func testLesFiltresEtLaRecherche() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "affaires"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Fuite d'eau au plafond du parking"].waitForExistence(timeout: 5))
        // La rangée de pastilles défile : « Résolues » est la dernière.
        let resolues = app.buttons["Résolues"]
        app.buttons["Toutes"].swipeLeft()
        XCTAssertTrue(resolues.waitForExistence(timeout: 3) && resolues.isHittable)
        resolues.tap()
        XCTAssertTrue(app.staticTexts["Portail du garage remis en service"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Fuite d'eau au plafond du parking"].exists)

        app.buttons["Résolues"].swipeRight()
        app.buttons["Toutes"].tap()
        app.swipeDown()
        let recherche = app.searchFields["Rechercher une affaire"]
        XCTAssertTrue(recherche.waitForExistence(timeout: 3))
        recherche.tap()
        recherche.typeText("ascenseur")
        XCTAssertTrue(app.staticTexts["Ascenseur du bâtiment B à l'arrêt"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Éclairage du hall en panne"].exists)
    }
}
