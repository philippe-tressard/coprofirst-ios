// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// L'activation de Face ID dit ce qui protège VRAIMENT la session gardée (#84) : Face
/// ID, ou le seul verrouillage de l'appareil — jamais l'un pour l'autre.
final class ProtectionUITests: XCTestCase {
    @MainActor
    private func activer(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "faceid"] + arguments
        app.launch()
        let activer = app.buttons["faceid.activer"]
        XCTAssertTrue(activer.waitForExistence(timeout: 5), "la proposition après la 1ʳᵉ connexion")
        activer.tap()
        return app
    }

    @MainActor
    func testAvecFaceIDLEcranDitFaceID() throws {
        let app = activer()
        let protection = app.staticTexts["faceid.protection"]
        XCTAssertTrue(protection.waitForExistence(timeout: 5))
        XCTAssertEqual(protection.label, "Protégée par Face ID")
        app.buttons["faceid.continuer"].tap()
        XCTAssertTrue(
            app.buttons["faceid.continuer"].waitForNonExistence(timeout: 5), "la feuille se ferme, le fil reste")
    }

    @MainActor
    func testSansBiometrieLEcranDitLeVerrouillageDeLAppareil() throws {
        let app = activer(["-protection", "appareil"])
        let protection = app.staticTexts["faceid.protection"]
        XCTAssertTrue(protection.waitForExistence(timeout: 5))
        XCTAssertEqual(protection.label, "Protégée par le verrouillage de l'appareil")
        XCTAssertFalse(protection.label.contains("Face ID"), "le repli ne se dit pas Face ID")
    }
}
