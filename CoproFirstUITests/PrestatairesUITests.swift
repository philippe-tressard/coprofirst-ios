// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// « Prestataires » (#13), sur l'API simulée : les trois onglets s'ouvrent depuis
/// « Plus », la recherche filtre, une fiche se déplie. Captures jointes. Recherche
/// par identifiant ou libellé, jamais par type (voir `AccesUITests`).
final class PrestatairesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLesTroisOngletsSOuvrent() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil"]
        app.launch()
        let barre = app.tabBars.firstMatch
        XCTAssertTrue(barre.waitForExistence(timeout: 5))
        barre.buttons["Plus"].tap()
        app.libelleAcces("Prestataires").tap()
        XCTAssertTrue(app.navigationBars["Prestataires"].waitForExistence(timeout: 3))

        let fiche = app.elementAcces("prestataire.1")
        XCTAssertTrue(fiche.waitForExistence(timeout: 5), "les fiches")
        app.capturerAcces("prestataires-1-liste", dans: self)
        fiche.tap()
        XCTAssertTrue(app.libelleAcces("Avis du conseil syndical (2)").waitForExistence(timeout: 3), "la fiche dépliée")
        app.capturerAcces("prestataires-2-fiche", dans: self)

        let recherche = app.elementAcces("prestataires.recherche")
        recherche.tap()
        recherche.typeText("incendie controles")
        XCTAssertTrue(app.elementAcces("prestataire.2").waitForExistence(timeout: 3))
        XCTAssertFalse(app.elementAcces("prestataire.1").exists, "la recherche filtre, sans accents ni ordre")
        recherche.typeText(XCUIKeyboardKey.delete.rawValue)

        app.elementAcces("onglet.contrats").tap()
        let contrat = app.elementAcces("contrat.1")
        XCTAssertTrue(contrat.waitForExistence(timeout: 5), "les contrats")
        contrat.tap()
        XCTAssertTrue(app.libelleAcces("Le contrat").waitForExistence(timeout: 3))
        XCTAssertTrue(app.libelleAcces("↺ Mensuel").exists, "la fréquence servie (`frequence_libelle`, #125)")
        app.capturerAcces("prestataires-3-contrats", dans: self)

        app.elementAcces("onglet.consommations").tap()
        // « 47 047 » : l'espace fine insécable de `fmtNombre`.
        XCTAssertTrue(app.libelleAcces("Index 47").waitForExistence(timeout: 5), "les relevés")
        app.capturerAcces("prestataires-4-consommations", dans: self)
    }
}
