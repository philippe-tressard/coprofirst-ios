// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// « Mes lots & accès » (#13), sur l'API simulée : chaque onglet s'ouvre, et les
/// gestes d'accès aboutissent. Chaque étape joint sa capture (gardée dans le
/// résultat du test : ce sont les captures de la PR).
final class AccesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func ouvrirAcces() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil"]
        app.launch()
        let barre = app.tabBars.firstMatch
        XCTAssertTrue(barre.waitForExistence(timeout: 5))
        barre.buttons["Accès"].tap()
        XCTAssertTrue(app.navigationBars["Mes lots & accès"].waitForExistence(timeout: 3))
        return app
    }

    @MainActor
    private func capturer(_ app: XCUIApplication, _ nom: String) {
        let piece = XCTAttachment(screenshot: app.screenshot())
        piece.name = nom
        piece.lifetime = .keepAlways
        add(piece)
    }

    @MainActor
    func testLesQuatreOngletsSOuvrent() throws {
        let app = ouvrirAcces()
        XCTAssertTrue(app.staticTexts["Caractéristiques"].waitForExistence(timeout: 5), "la carte du lot")
        capturer(app, "acces-1-mes-lots")

        app.buttons["acces.lot.417"].tap()
        XCTAssertTrue(app.staticTexts["Sous-sol A"].waitForExistence(timeout: 3), "le lot choisi s'affiche")

        app.buttons["onglet.badges"].tap()
        XCTAssertTrue(app.staticTexts["A4F21C07"].waitForExistence(timeout: 5), "les badges détenus")
        capturer(app, "acces-2-badges")

        app.buttons["onglet.telecommandes"].tap()
        XCTAssertTrue(app.staticTexts["TC-2048"].waitForExistence(timeout: 5), "les télécommandes détenues")
        capturer(app, "acces-3-telecommandes")

        // Le compte simulé est au conseil syndical : la gestion locative lui est ouverte.
        app.buttons["onglet.telecommandes"].swipeLeft()
        app.buttons["onglet.location"].tap()
        XCTAssertTrue(app.staticTexts["Locataire du lot 31"].waitForExistence(timeout: 5), "un bail actif")
        capturer(app, "acces-4-gestion-locative")
        app.segmentedControls.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["Ancien locataire du lot 31"].waitForExistence(timeout: 3), "les archives")
    }

    @MainActor
    func testSignalerPerduPuisDeclarer() throws {
        let app = ouvrirAcces()
        app.buttons["onglet.badges"].tap()
        let perdu = app.buttons["acces.perdu.12"]
        XCTAssertTrue(perdu.waitForExistence(timeout: 5))
        perdu.tap()
        // Le bouton de la confirmation, pas celui d'une ligne.
        app.buttons.matching(
            NSPredicate(format: "label == %@ AND NOT (identifier BEGINSWITH %@)", "Signaler perdu", "acces.perdu")
        ).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Signalement enregistré"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["acces.perdu.12"].exists, "un accès perdu ne se signale plus")

        app.buttons["acces.gestes"].tap()
        app.buttons["Déclarer un accès"].tap()
        let code = app.textFields["acces.declarer.code"]
        XCTAssertTrue(code.waitForExistence(timeout: 3))
        code.typeText("TC-7777")
        capturer(app, "acces-5-declarer")
        app.buttons["acces.feuille.enregistrer"].tap()
        XCTAssertTrue(app.staticTexts["Accès enregistré"].waitForExistence(timeout: 5))
        app.buttons["onglet.telecommandes"].tap()
        XCTAssertTrue(app.staticTexts["TC-7777"].waitForExistence(timeout: 5), "la liste est relue")
    }

    @MainActor
    func testNouvelAccesNeProposeQueSesLots() throws {
        let app = ouvrirAcces()
        app.buttons["onglet.badges"].tap()
        app.buttons["acces.gestes"].tap()
        app.buttons["Nouvel accès"].tap()
        XCTAssertTrue(app.navigationBars["Nouvelle demande d'accès"].waitForExistence(timeout: 3))
        app.buttons["acces.feuille.enregistrer"].tap()
        let exige = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Sélectionnez un lot")).firstMatch
        XCTAssertTrue(exige.waitForExistence(timeout: 3), "un lot est exigé")
        app.buttons["acces.demande.lot"].tap()
        XCTAssertTrue(app.buttons["Lot 15"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Lot 450"].exists)
        app.buttons["Lot 15"].tap()
        capturer(app, "acces-6-nouvel-acces")
        app.buttons["acces.feuille.enregistrer"].tap()
        XCTAssertTrue(app.staticTexts["Demande envoyée au conseil syndical"].waitForExistence(timeout: 5))
    }
}
