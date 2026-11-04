// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// « Prestataires » (#13), sur l'API simulée : les trois onglets s'ouvrent depuis
/// « Plus », la recherche filtre, une fiche se déplie. Captures jointes.
final class PrestatairesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func capturer(_ app: XCUIApplication, _ nom: String) {
        let piece = XCTAttachment(screenshot: app.screenshot())
        piece.name = nom
        piece.lifetime = .keepAlways
        add(piece)
    }

    @MainActor
    func testLesTroisOngletsSOuvrent() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil"]
        app.launch()
        let barre = app.tabBars.firstMatch
        XCTAssertTrue(barre.waitForExistence(timeout: 5))
        barre.buttons["Plus"].tap()
        app.buttons["Prestataires"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Prestataires"].waitForExistence(timeout: 3))

        let fiche = app.buttons["prestataire.1"]
        XCTAssertTrue(fiche.waitForExistence(timeout: 5), "les fiches")
        capturer(app, "prestataires-1-liste")
        fiche.tap()
        XCTAssertTrue(app.staticTexts["Avis du conseil syndical (2)"].waitForExistence(timeout: 3), "la fiche dépliée")
        capturer(app, "prestataires-2-fiche")

        let recherche = app.textFields["prestataires.recherche"]
        recherche.tap()
        recherche.typeText("incendie controles")
        XCTAssertTrue(app.buttons["prestataire.2"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["prestataire.1"].exists, "la recherche filtre, sans accents ni ordre")
        recherche.typeText(XCUIKeyboardKey.delete.rawValue)

        app.buttons["onglet.contrats"].tap()
        let contrat = app.buttons["contrat.1"]
        XCTAssertTrue(contrat.waitForExistence(timeout: 5), "les contrats")
        contrat.tap()
        XCTAssertTrue(app.staticTexts["Le contrat"].waitForExistence(timeout: 3))
        capturer(app, "prestataires-3-contrats")

        app.buttons["onglet.consommations"].tap()
        // « 47 047 » : l'espace fine insécable de `fmtNombre`.
        let index = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Index 47")).firstMatch
        XCTAssertTrue(index.waitForExistence(timeout: 5), "les relevés")
        capturer(app, "prestataires-4-consommations")
    }
}
