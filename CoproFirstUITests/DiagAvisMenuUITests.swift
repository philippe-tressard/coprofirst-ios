// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// DIAGNOSTIC TEMPORAIRE (#48) — jamais fusionné : sous iOS 26.5, le menu « + » et
/// la feuille « Déclarer » face au retrait de l'avis éphémère.
final class DiagAvisMenuUITests: XCTestCase {
    @MainActor
    private func surBadges() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        app.tabBars.firstMatch.buttons["Accès"].tap()
        XCTAssertTrue(app.navigationBars["Mes lots & accès"].waitForExistence(timeout: 3))
        app.elementAcces("onglet.badges").tap()
        XCTAssertTrue(app.elementAcces("acces.perdu.12").waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func signaler(_ app: XCUIApplication) -> XCUIElement {
        app.elementAcces("acces.perdu.12").tap()
        app.elementAcces("acces.perdu.confirmer").tap()
        let avis = app.libelleAcces("Signalement enregistré")
        XCTAssertTrue(avis.waitForExistence(timeout: 3))
        return avis
    }

    @MainActor
    private func declarer(_ app: XCUIApplication, _ etape: String) {
        let ouverte = app.elementAcces("acces.declarer.code").waitForExistence(timeout: 4)
        print("DIAGMENU[\(etape)] feuille=\(ouverte)")
        if !ouverte { print("DIAGMENU[\(etape)] ARBRE\n\(app.debugDescription)") }
        XCTAssertTrue(ouverte, etape)
    }

    /// C : aucun avis — le menu puis la feuille.
    @MainActor
    func testC_SansAvis() {
        let app = surBadges()
        app.elementAcces("acces.gestes").tap()
        app.elementAcces("acces.geste.declarer").tap()
        declarer(app, "C")
    }

    /// A : l'avis s'est retiré AVANT d'ouvrir le menu.
    @MainActor
    func testA_AvisRetireAvantLeMenu() {
        let app = surBadges()
        XCTAssertTrue(signaler(app).waitForNonExistence(timeout: 6))
        app.elementAcces("acces.gestes").tap()
        app.elementAcces("acces.geste.declarer").tap()
        declarer(app, "A")
    }

    /// B : le menu est ouvert pendant que l'avis se retire.
    @MainActor
    func testB_AvisSeRetireMenuOuvert() {
        let app = surBadges()
        let avis = signaler(app)
        app.elementAcces("acces.gestes").tap()
        let item = app.elementAcces("acces.geste.declarer")
        print("DIAGMENU[B] menu ouvert, avis=\(avis.exists) item=\(item.exists)")
        XCTAssertTrue(avis.waitForNonExistence(timeout: 6))
        print("DIAGMENU[B] avis retiré, item=\(item.exists)")
        if !item.exists { print("DIAGMENU[B] ARBRE-MENU\n\(app.debugDescription)") }
        XCTAssertTrue(item.exists, "le menu reste ouvert quand l'avis se retire")
        item.tap()
        declarer(app, "B")
    }

    /// D : la feuille de déclaration demandée PENDANT le retrait de l'avis.
    @MainActor
    func testD_ToucherPendantLeRetrait() {
        let app = surBadges()
        let avis = signaler(app)
        app.elementAcces("acces.gestes").tap()
        let item = app.elementAcces("acces.geste.declarer")
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        // Toucher au moment où l'avis disparaît : on le guette sans attendre l'inactivité.
        let debut = Date()
        while avis.exists, Date().timeIntervalSince(debut) < 6 { usleep(50_000) }
        print("DIAGMENU[D] avis retiré après \(Date().timeIntervalSince(debut)) s, item=\(item.exists)")
        item.tap()
        declarer(app, "D")
    }
}
