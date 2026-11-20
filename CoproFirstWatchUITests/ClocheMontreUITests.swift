// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// La cloche au poignet (#226), sur la résidence inventée (`-api-simulee`) : l'urgente
/// devant, l'alerte qui s'ouvre en entier, les lues repliées — et ce que la montre dit sans
/// liaison, sans alerte ou sans réseau. Les éléments se trouvent par leur identifiant, jamais
/// par leur type. L'ordre se prouve aussi, sans écran, dans `ClocheTests`.
final class ClocheMontreUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func lancer(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ identifiant: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifiant).firstMatch
    }

    @MainActor
    func testSansLiaisonLaMontreDitDeLaRelierParLIPhone() {
        let app = lancer([])
        XCTAssertTrue(element(app, "montre.nonReliee").apparait())
        XCTAssertFalse(element(app, "montre.cloche").exists)
    }

    @MainActor
    func testLUrgenteNonLuePasseDevant() {
        let app = lancer(["-api-simulee", "-cloche", "10"])
        let urgente = element(app, "montre.alerte.4")
        XCTAssertTrue(urgente.apparait(), "l'alerte urgente de la boîte simulée")
        // La suivante peut être sous le bord d'un écran de montre : amenée pour être lue.
        let autre = element(app, "montre.alerte.5")
        XCTAssertTrue(app.amener(autre, pourLire: true))
        XCTAssertLessThan(urgente.frame.minY, autre.frame.minY, "l'urgente passe devant la non lue ordinaire")
    }

    @MainActor
    func testUneAlerteSOuvreEnEntier() {
        let app = lancer(["-api-simulee", "-cloche", "10"])
        app.toucher(element(app, "montre.alerte.4"))
        XCTAssertTrue(element(app, "montre.detail.4").apparait())
        XCTAssertTrue(element(app, "montre.corps").apparait(), "le corps de l'alerte en entier")
    }

    @MainActor
    func testLesDejaLuesSontRepliees() {
        let app = lancer(["-api-simulee", "-cloche", "10"])
        let dejaLues = element(app, "montre.dejaLues")
        XCTAssertTrue(app.amener(dejaLues))
        XCTAssertFalse(element(app, "montre.alerte.3").exists, "une lue reste repliée")
        app.toucher(dejaLues)
        // Lue, pas touchée : sous watchOS, une ligne hors de l'écran lève à la question
        // « touchable ? » au lieu de répondre non — on l'amène pour la lire.
        XCTAssertTrue(app.amener(element(app, "montre.alerte.3"), pourLire: true), "dépliées, les lues paraissent")
    }

    @MainActor
    func testSansAlerteLaClocheLeDit() {
        let app = lancer(["-api-simulee", "-cloche", "vide"])
        XCTAssertTrue(element(app, "montre.vide").apparait())
        XCTAssertFalse(element(app, "montre.dejaLues").exists)
    }

    @MainActor
    func testUneResidenceQuiNeRepondPasSeDit() {
        let app = lancer(["-api-simulee", "-cloche", "injoignable"])
        XCTAssertTrue(element(app, "montre.injoignable").apparait())
    }

    /// Le serveur ne reconnaît plus le jeton (#226) : la montre ne dit pas « injoignable »,
    /// elle oublie la liaison et dit de la relier par l'iPhone.
    @MainActor
    func testUnJetonRefuseRameneALaLiaison() {
        let app = lancer(["-api-simulee", "-cloche", "refusee"])
        XCTAssertTrue(element(app, "montre.nonReliee").apparait())
        XCTAssertFalse(element(app, "montre.injoignable").exists)
    }

    /// Sans réseau, la dernière cloche gardée se montre, datée (#226, lot 3).
    @MainActor
    func testSansReseauLaClocheGardeeSeMontreDatee() {
        let app = lancer(["-api-simulee", "-cloche", "horsligne"])
        XCTAssertTrue(element(app, "montre.horsLigne").apparait())
        XCTAssertTrue(element(app, "montre.alerte.4").apparait(), "les alertes gardées")
        XCTAssertFalse(element(app, "montre.injoignable").exists)
    }
}
