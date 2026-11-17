// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// La barre latérale de l'iPad en plein écran — classe de taille régulière (#221). Les
/// pendants des tests de la barre du bas (`ParcoursUITests`), qui n'ont pas cours sur iPad.
///
/// Sautés sur iPhone : le test choisit son appareil, l'app, elle, ne lit que la classe de
/// taille (`PresentationNavigation.pour`). Joués par l'échantillon iPad de la CI.
final class BarreLateraleUITests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "la barre latérale : iPad en plein écran")
    }

    private func lancer(_ arguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil"] + arguments
        app.launch()
        return app
    }

    private func entree(_ id: String, dans app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "barre.\(id)").firstMatch
    }

    /// Toutes les pages, sans « Plus » : les quatre de la barre du bas, celles d'au-delà,
    /// Profil et À propos — chacune sous son libellé de barre, son écran sous son titre.
    @MainActor
    func testLaBarreLateraleListeToutesLesPages() throws {
        let app = lancer()
        let ids = ["tableau-de-bord", "residence", "mes-demandes", "mon-lot", "annuaire", "faq", "profil", "a-propos"]
        for id in ids {
            XCTAssertTrue(entree(id, dans: app).apparait(), "« \(id) » dans la barre latérale")
        }
        XCTAssertFalse(entree("plus", dans: app).exists, "pas de « Plus » : tout tient")
        XCTAssertEqual(entree("mon-lot", dans: app).label, "Accès", "le libellé de la barre, écrit une fois")

        // Le premier toucher après un lancement lent pouvait se perdre (#282) : chaque page
        // s'ouvre JUSQU'À son titre, et une reprise se déclare au résumé du run.
        app.toucher(entree("mon-lot", dans: app), jusqua: app.navigationBars["Mes lots & accès"])
        app.toucher(entree("faq", dans: app), jusqua: app.navigationBars["FAQ"])
        app.toucher(entree("profil", dans: app), jusqua: app.navigationBars["Profil"])
        XCTAssertTrue(app.buttons["pastille.residence"].apparait(), "« où suis-je » sur le Profil aussi")
    }

    @MainActor
    func testUnePageRenommeeGardeSonNomDansLaBarreLaterale() throws {
        let app = lancer("-page-renommee")
        let page = entree("mon-lot", dans: app)
        XCTAssertTrue(page.apparait())
        XCTAssertEqual(page.label, "Clés et badges")
    }

    /// Le logement du fil ouvre Mes lots & accès : l'entrée de la barre latérale suit, et la
    /// pastille de la résidence et la cloche restent dans la barre du fil.
    @MainActor
    func testLeLogementOuvreSaPageDansLaBarreLaterale() throws {
        let app = lancer("-logement-long")
        let logement = app.buttons["fil.lot"]
        XCTAssertTrue(logement.apparait())
        XCTAssertTrue(app.buttons["pastille.residence"].apparait(), "la résidence reste dans la barre")
        XCTAssertTrue(app.buttons["cloche"].apparait(), "la cloche aussi")

        app.toucher(logement, jusqua: app.navigationBars["Mes lots & accès"])
        XCTAssertTrue(app.elementRetenu("barre.mon-lot").apparait(), "l'entrée Accès est retenue")
    }
}
