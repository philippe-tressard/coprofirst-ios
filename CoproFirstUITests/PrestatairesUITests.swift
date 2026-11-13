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
        XCTAssertTrue(barre.apparait())
        barre.buttons["Plus"].tap()
        app.libelleAcces("Prestataires").tap()
        XCTAssertTrue(app.navigationBars["Prestataires"].apparait())

        let fiche = app.elementAcces("prestataire.1")
        XCTAssertTrue(fiche.apparait(), "les fiches")
        app.capturerAcces("prestataires-1-liste", dans: self)
        fiche.tap()
        XCTAssertTrue(app.libelleAcces("Avis du conseil syndical (2)").apparait(), "la fiche dépliée")
        app.capturerAcces("prestataires-2-fiche", dans: self)

        let recherche = app.elementAcces("prestataires.recherche")
        recherche.tap()
        recherche.typeText("incendie controles")
        XCTAssertTrue(app.elementAcces("prestataire.2").apparait())
        XCTAssertFalse(app.elementAcces("prestataire.1").exists, "la recherche filtre, sans accents ni ordre")
        recherche.typeText(XCUIKeyboardKey.delete.rawValue)

        app.elementAcces("onglet.contrats").tap()
        let contrat = app.elementAcces("contrat.1")
        XCTAssertTrue(contrat.apparait(), "les contrats")
        contrat.tap()
        XCTAssertTrue(app.libelleAcces("Le contrat").apparait())
        XCTAssertTrue(app.libelleAcces("↺ Mensuel").exists, "la fréquence servie (`frequence_libelle`, #125)")
        app.capturerAcces("prestataires-3-contrats", dans: self)

        // 🔁 Le remplacement servi (#185, contrat 1.29.0), sur les deux cartes.
        let remplace = app.elementAcces("contrat.2.remplacement.0")
        XCTAssertTrue(remplace.apparait(), "l'ancien contrat dit par qui il est remplacé")
        XCTAssertEqual(remplace.label, "🔁 Remplacé par Protection Incendie Exemple ·\u{00A0}dès le 01/12/2026")
        let remplacant = app.elementAcces("contrat.4.remplacement.0")
        XCTAssertTrue(remplacant.apparait(), "le nouveau dit qui il remplace")
        XCTAssertEqual(remplacant.label, "🔁 Remplace Contrôles Sécurité Exemple (résilié au 30/11/2026)")
        XCTAssertFalse(app.elementAcces("contrat.1.remplacement.0").exists, "sans remplacement : rien")
        app.capturerAcces("prestataires-3b-remplacement", dans: self)

        app.elementAcces("onglet.consommations").tap()
        // « 47 047 » : l'espace fine insécable de `fmtNombre`.
        XCTAssertTrue(app.libelleAcces("Index 47").apparait(), "les relevés")
        app.capturerAcces("prestataires-4-consommations", dans: self)
    }
}
