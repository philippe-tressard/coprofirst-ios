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
        XCTAssertTrue(activer.apparait(), "la proposition après la 1ʳᵉ connexion")
        activer.tap()
        return app
    }

    /// La biométrie que le MODÈLE simulé porte — un oracle indépendant de l'app, qui lit
    /// `LAContext` : Touch ID sur un iPad Air, un iPad mini ou l'iPad d'entrée, Face ID
    /// ailleurs (#223).
    private static var biometrieDuModele: String {
        let modele = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? ""
        let aTouchID = ["iPad Air", "iPad mini", "iPad ("].contains { modele.hasPrefix($0) }
        return aTouchID ? "Touch ID" : "Face ID"
    }

    /// La question et le résultat nomment la biométrie de l'appareil : « Touch ID » sur un
    /// iPad Air ou mini, jamais « Face ID » d'office (#223).
    @MainActor
    func testAvecLaBiometrieLEcranLaNommeDApresLAppareil() throws {
        let attendue = Self.biometrieDuModele
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "faceid"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Ouvrir avec \(attendue) ?"].apparait(), "la question nomme \(attendue)")
        app.toucher(app.buttons["faceid.activer"])
        let protection = app.staticTexts["faceid.protection"]
        XCTAssertTrue(protection.apparait())
        XCTAssertEqual(protection.label, "Protégée par \(attendue)")
        app.buttons["faceid.continuer"].tap()
        XCTAssertTrue(
            app.buttons["faceid.continuer"].disparait(), "la feuille se ferme, le fil reste")
    }

    @MainActor
    func testSansBiometrieLEcranDitLeVerrouillageDeLAppareil() throws {
        let app = activer(["-protection", "appareil"])
        let protection = app.staticTexts["faceid.protection"]
        XCTAssertTrue(protection.apparait())
        XCTAssertEqual(protection.label, "Protégée par le verrouillage de l'appareil")
        XCTAssertFalse(protection.label.contains("Face ID"), "le repli ne se dit pas Face ID")
    }
}
