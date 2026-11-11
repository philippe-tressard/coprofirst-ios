// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Le retour d'un habitué : jamais l'accueil ni la démo — Face ID et le fil, ou la
/// connexion pré-remplie. Contre l'API simulée : aucune requête ne part.
final class RetourUITests: XCTestCase {
    private func element(_ app: XCUIApplication, _ identifiant: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifiant).firstMatch
    }

    @MainActor
    func testUneSessionGardeeOuvreLeFilSansPasserParLAccueil() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "retour"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Fuite d'eau au plafond du parking"].apparait(), "le fil")
        XCTAssertFalse(element(app, "accueil.demo").exists, "ni l'accueil ni la démo")
    }

    @MainActor
    func testFaceIDAnnuleLaisseLeChoixEtLeMotDePasseNeLeRedemandePas() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "retour", "-faceid-refuse"]
        app.launch()
        XCTAssertTrue(element(app, "retour.ouvrir").apparait(), "Face ID se redemande d'un toucher")
        XCTAssertTrue(element(app, "retour.residence").exists, "la résidence, pas l'accueil")
        XCTAssertFalse(element(app, "accueil.demo").exists)

        element(app, "retour.motDePasse").tap()
        let email = element(app, "connexion.email")
        XCTAssertTrue(email.apparait())
        XCTAssertEqual(email.value as? String, "resident@exemple.fr", "le courriel retenu")
        XCTAssertEqual(element(app, "connexion.residence").value as? String, "tilleuls.exemple.fr")
        XCTAssertFalse(app.tabBars.firstMatch.exists, "rien ne s'est ouvert par Face ID")
    }

    @MainActor
    func testSansFaceIDIlNeResteQueLeMotDePasse() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "retour-mot-de-passe"]
        app.launch()
        let email = element(app, "connexion.email")
        XCTAssertTrue(email.apparait(), "la connexion d'emblée")
        XCTAssertEqual(email.value as? String, "resident@exemple.fr", "le courriel retenu")
        XCTAssertFalse(element(app, "accueil.demo").exists, "ni l'accueil ni la démo")

        let motDePasse = element(app, "connexion.motDePasse")
        // Le curseur attend dans le mot de passe : on tape sans toucher le champ.
        XCTAssertTrue(motDePasse.attendre("hasKeyboardFocus == true"), "le curseur attend dans le mot de passe")
        motDePasse.typeText("secret\n")
        XCTAssertTrue(app.staticTexts["Fuite d'eau au plafond du parking"].apparait(), "le fil")
    }
}
