// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Une installation suspendue par la référence, en lecture seule (Registre R6, #262) : le
/// bandeau du site en tête de chaque page, et dans la connexion — rien pour une ordinaire.
final class InstallationSuspendueUITests: XCTestCase {
    private static let bandeau = "bandeau.installation"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func lancer(_ arguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee"] + arguments
        app.launch()
        return app
    }

    @MainActor
    func testLaSuspensionSeDitEnTeteDeChaquePage() throws {
        let app = lancer("-ecran", "fil", "-installation-suspendue")
        let bandeau = app.elementAcces(Self.bandeau)
        XCTAssertTrue(bandeau.apparait(), "le bandeau en tête du Fil")
        // Le tiret du site : une espace sécable avant, INSÉCABLE après (`Separateur.tiret`).
        XCTAssertTrue(bandeau.label.hasPrefix("Installation suspendue —\u{00A0}lecture seule."), bandeau.label)
        XCTAssertTrue(bandeau.label.contains("Tout reste consultable"), "le texte publié, entier")
        LancementCaptures.capturer("installation-suspendue-fil")

        app.toucher(app.tabBars.buttons["Résidence"])
        XCTAssertTrue(app.staticTexts["AA0-000-000"].apparait())
        XCTAssertTrue(app.elementAcces(Self.bandeau).apparait(), "et sur l'autre page")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: Self.bandeau).count, 1, "une fois")
    }

    @MainActor
    func testLeRetourDitLaSuspensionSousLeNom() throws {
        let app = lancer("-ecran", "retour", "-installation-suspendue", "-faceid-refuse")
        XCTAssertTrue(app.elementAcces("retour.residence").apparait())
        XCTAssertTrue(app.elementAcces(Self.bandeau).apparait(), "sous le nom de la résidence")
    }

    @MainActor
    func testLaConnexionDitLaSuspensionAvantDEntrer() throws {
        let app = lancer("-ecran", "connexion", "-installation-suspendue")
        XCTAssertTrue(app.elementAcces(Self.bandeau).apparait(), "on se connecte encore, pour lire")
        XCTAssertTrue(app.elementAcces("connexion.email").exists)
    }

    @MainActor
    func testUneInstallationOrdinaireNeDitRien() throws {
        let app = lancer("-ecran", "fil")
        XCTAssertTrue(app.buttons["fil.ticket_ouvert:41"].apparait(), "le Fil est chargé")
        XCTAssertFalse(app.elementAcces(Self.bandeau).sonde(), "aucun bandeau : il ne coûte rien")
    }
}
