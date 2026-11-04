// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Le menu Affaires contre l'API simulée (un compte du conseil syndical) : Liste,
/// Kanban, Archives et « Nouvelle affaire ».
///
/// `CAPTURES_AFFAIRES` (passé par `TEST_RUNNER_CAPTURES_AFFAIRES`) : le dossier où
/// chaque étape dépose sa capture — celles de la PR.
final class AffairesUITests: XCTestCase {
    private func lancer() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "affaires"]
        app.launch()
        let onglet = app.buttons["Affaires"].firstMatch
        XCTAssertTrue(onglet.waitForExistence(timeout: 5))
        onglet.tap()
        return app
    }

    private func capturer(_ nom: String) {
        guard let dossier = ProcessInfo.processInfo.environment["CAPTURES_AFFAIRES"] else { return }
        let donnees = XCUIScreen.main.screenshot().pngRepresentation
        try? donnees.write(to: URL(fileURLWithPath: dossier).appendingPathComponent("\(nom).png"))
    }

    /// Aux très grandes tailles de texte, le champ est plus bas que l'écran.
    @MainActor
    private func atteindre(_ element: XCUIElement, dans app: XCUIApplication) {
        var essais = 0
        while !(element.exists && element.isHittable), essais < 8 {
            app.swipeUp()
            essais += 1
        }
    }

    @MainActor
    func testLesTroisOngletsEtLaCreation() throws {
        let app = lancer()
        let carte = app.buttons["affaires.carte.A-0041"]
        XCTAssertTrue(carte.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["affaires.carte.A-0022"].exists, "une archivée n'est pas dans la Liste")
        capturer("1-liste")

        app.buttons["Kanban"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["kanban.colonne.cs"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["kanban.carte.A-0035"].exists, "« Ouvert » se range dans la colonne CS")
        capturer("2-kanban")

        app.buttons["Archives"].firstMatch.tap()
        XCTAssertTrue(app.buttons["archives.carte.A-0022"].waitForExistence(timeout: 5))
        capturer("3-archives")

        app.buttons["Liste"].firstMatch.tap()
        app.buttons["affaires.nouvelle"].tap()
        let panne = app.buttons["nouvelle.categorie.panne"]
        XCTAssertTrue(panne.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["nouvelle.envoyer"].isEnabled, "rien n'est saisi")
        panne.tap()
        capturer("4-categories")
        let titre = app.textFields["nouvelle.titre"]
        atteindre(titre, dans: app)
        titre.tap()
        titre.typeText("Porte du local vélos bloquée")
        let description = app.textFields["nouvelle.description"]
        atteindre(description, dans: app)
        description.tap()
        description.typeText("La serrure ne tourne plus depuis ce matin.")
        capturer("5-saisie")
        app.buttons["nouvelle.envoyer"].tap()
        XCTAssertTrue(
            app.staticTexts["Porte du local vélos bloquée"].waitForExistence(timeout: 5),
            "l'affaire créée paraît en tête de la Liste")
        capturer("6-creee")
    }

    @MainActor
    func testUneCarteOuvreSonDetail() throws {
        let app = lancer()
        let carte = app.buttons["affaires.carte.A-0041"]
        XCTAssertTrue(carte.waitForExistence(timeout: 5))
        carte.tap()
        XCTAssertTrue(app.navigationBars["A-0041"].waitForExistence(timeout: 5))
    }
}
