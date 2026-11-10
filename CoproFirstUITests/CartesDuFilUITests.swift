// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Chaque carte du fil s'ouvre, contre l'API simulée.
final class CartesDuFilUITests: XCTestCase {
    private func lancer() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil"]
        app.launch()
        return app
    }

    @MainActor
    func testUneAffaireSOuvreEtSeRepond() throws {
        let app = lancer()
        let carte = app.buttons["fil.ticket_ouvert:41"]
        XCTAssertTrue(carte.waitForExistence(timeout: 5))
        carte.tap()
        XCTAssertTrue(app.navigationBars["A-0041"].waitForExistence(timeout: 5))
        // La carte de l'Historique se lit d'un bloc (VoiceOver) : on cherche dans son libellé.
        let changement = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Ouvert → Chez le syndic")).firstMatch
        XCTAssertTrue(changement.exists)

        app.buttons["affaire.repondre"].tap()
        let texte = app.textViews["repondre.texte"]
        XCTAssertTrue(texte.waitForExistence(timeout: 3))
        texte.typeText("Merci, je contourne la zone.")
        app.buttons["repondre.envoyer"].tap()
        XCTAssertTrue(app.buttons["affaire.repondre"].waitForExistence(timeout: 5), "la feuille se referme")
    }

    @MainActor
    func testUnSondageUnDocumentEtUnResumeSOuvrent() throws {
        let app = lancer()
        let sondage = app.buttons["fil.sondage_ouvert:3"]
        XCTAssertTrue(sondage.waitForExistence(timeout: 5))
        sondage.tap()
        XCTAssertTrue(app.elementAcces("sondage.option.1").waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        let document = app.buttons["fil.document:7"]
        XCTAssertTrue(document.waitForExistence(timeout: 5))
        document.tap()
        XCTAssertTrue(app.navigationBars["Procès-verbal de l'assemblée générale"].waitForExistence(timeout: 8))
        app.navigationBars.buttons.firstMatch.tap()

        let point = app.buttons["fil.point_conseil:2"]
        if !point.isHittable { app.swipeUp() }
        XCTAssertTrue(point.waitForExistence(timeout: 5))
        point.tap()
        XCTAssertTrue(
            app.staticTexts["Ordre du jour : ascenseur, ravalement, contrat d'entretien."].waitForExistence(timeout: 5))
    }
}
