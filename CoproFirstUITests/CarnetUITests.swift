// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Le carnet de l'iPhone pliable ouvert (#119) : les intercalaires sur la tranche droite, à
/// la place de la barre du bas. Joué en classe régulière, la charnière fixée par
/// `-posture deplie` : un simulateur iPad sert au poste comme en CI, qui n'a ni iOS 27.1 ni
/// l'iPhone Duo. Sur l'iPhone Duo déplié, la vraie charnière se lit, au poste seulement.
///
/// Sautés sur iPhone (classe compacte) : le test choisit son appareil, l'app, elle, ne lit
/// que la classe de taille et la charnière (`PresentationNavigation.pour`).
final class CarnetUITests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "le carnet : classe régulière")
    }

    private func lancer(_ arguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil", "-posture", "deplie"] + arguments
        app.launch()
        return app
    }

    private func intercalaire(_ id: String, dans app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "carnet.\(id)").firstMatch
    }

    /// Toutes les pages en intercalaires, dans l'ordre réglé, sans « Plus » ni barre latérale ;
    /// un toucher ouvre la page, et l'intercalaire ouvert se dit retenu.
    @MainActor
    func testLesIntercalairesOuvrentToutesLesPages() throws {
        let app = lancer()
        let ids = ["tableau-de-bord", "residence", "mes-demandes", "mon-lot", "annuaire", "faq", "profil", "a-propos"]
        for id in ids {
            XCTAssertTrue(intercalaire(id, dans: app).apparait(), "« \(id) » en intercalaire")
        }
        let barre = app.descendants(matching: .any).matching(identifier: "barre.faq").firstMatch
        XCTAssertFalse(barre.sonde(), "pas de barre latérale : le carnet la remplace")
        XCTAssertEqual(intercalaire("mon-lot", dans: app).label, "Accès", "le libellé de la barre, écrit une fois")

        app.toucher(intercalaire("faq", dans: app))
        XCTAssertTrue(app.navigationBars["FAQ"].apparait(), "une page d'au-delà de la barre du bas, d'un toucher")
        let retenu = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND isSelected == true", "carnet.faq")).firstMatch
        XCTAssertTrue(retenu.apparait(), "l'intercalaire ouvert est retenu")

        app.toucher(intercalaire("profil", dans: app))
        XCTAssertTrue(app.navigationBars["Profil"].apparait())
        XCTAssertTrue(app.buttons["pastille.residence"].apparait(), "« où suis-je » sur chaque page du carnet")
    }

    /// Une page renommée par l'administration garde son nom sur la tranche aussi.
    @MainActor
    func testUnePageRenommeeGardeSonNomSurLaTranche() throws {
        let app = lancer("-page-renommee")
        let page = intercalaire("mon-lot", dans: app)
        XCTAssertTrue(page.apparait())
        XCTAssertEqual(page.label, "Clés et badges")
    }
}
