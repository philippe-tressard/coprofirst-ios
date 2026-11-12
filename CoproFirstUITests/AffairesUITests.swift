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
        let onglet = app.descendants(matching: .any)["Affaires"].firstMatch
        XCTAssertTrue(onglet.apparait())
        onglet.tap()
        return app
    }

    /// Un élément par son identifiant, QUEL QUE SOIT SON TYPE : un même contrôle n'a pas
    /// le même type d'accessibilité sous iOS 26.5 (CI) et 27.2 (poste) — leçon de #12.
    private func element(_ identifiant: String, dans app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifiant).firstMatch
    }

    /// Un contrôle de cet identifiant est-il désactivé ? Sous iOS 26.5, le premier élément
    /// qui porte l'identifiant d'un bouton de barre est un conteneur (« Other ») toujours
    /// actif : on interroge TOUS les éléments de l'identifiant, quel que soit leur type.
    private func desactive(_ identifiant: String, dans app: XCUIApplication) -> Bool {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND isEnabled == false", identifiant))
            .firstMatch.exists
    }

    private func capturer(_ nom: String) {
        guard let dossier = ProcessInfo.processInfo.environment["CAPTURES_AFFAIRES"] else { return }
        let donnees = XCUIScreen.main.screenshot().pngRepresentation
        try? donnees.write(to: URL(fileURLWithPath: dossier).appendingPathComponent("\(nom).png"))
    }

    /// Aux très grandes tailles de texte, le champ est plus bas que l'écran.
    @MainActor
    func testLesTroisOngletsEtLaCreation() throws {
        let app = lancer()
        let carte = element("affaires.carte.A-0041", dans: app)
        XCTAssertTrue(carte.apparait())
        XCTAssertFalse(element("affaires.carte.A-0022", dans: app).exists, "une archivée n'est pas dans la Liste")
        capturer("1-liste")

        app.descendants(matching: .any)["Kanban"].firstMatch.tap()
        XCTAssertTrue(element("kanban.colonne.cs", dans: app).apparait())
        XCTAssertTrue(element("kanban.carte.A-0035", dans: app).exists, "« Ouvert » se range dans la colonne CS")
        capturer("2-kanban")

        app.descendants(matching: .any)["Archives"].firstMatch.tap()
        XCTAssertTrue(element("archives.carte.A-0022", dans: app).apparait())
        capturer("3-archives")

        app.descendants(matching: .any)["Liste"].firstMatch.tap()
        element("affaires.nouvelle", dans: app).tap()
        let panne = element("nouvelle.categorie.panne", dans: app)
        XCTAssertTrue(panne.apparait())
        XCTAssertTrue(desactive("nouvelle.envoyer", dans: app), "rien n'est saisi : Envoyer est désactivé")
        panne.tap()
        capturer("4-categories")
        let titre = element("nouvelle.titre", dans: app)
        app.amener(titre)
        titre.tap()
        titre.typeText("Porte du local vélos bloquée")
        let description = element("nouvelle.description", dans: app)
        app.amener(description)
        description.tap()
        description.typeText("La serrure ne tourne plus depuis ce matin.")
        capturer("5-saisie")
        XCTAssertFalse(desactive("nouvelle.envoyer", dans: app), "titre et description saisis : Envoyer s'active")
        element("nouvelle.envoyer", dans: app).tap()
        XCTAssertTrue(
            element("affaires.carte.A-0042", dans: app).apparait(),
            "l'affaire créée paraît en tête de la Liste")
        capturer("6-creee")
    }

    @MainActor
    func testUneCarteOuvreSonDetail() throws {
        let app = lancer()
        let carte = element("affaires.carte.A-0041", dans: app)
        XCTAssertTrue(carte.apparait())
        carte.tap()
        XCTAssertTrue(app.attendreDetailAffaire("A-0041"))
        // Qui la lit, telle que servie (#129) : dans l'en-tête, chargée avec le détail.
        XCTAssertTrue(element("lecture.detail", dans: app).exists, "la phrase de la pastille servie")
    }

    @MainActor
    func testLeFiltreSuiviNeGardeQueSonEtat() throws {
        let app = lancer()
        XCTAssertTrue(element("affaires.carte.A-0041", dans: app).apparait())
        let resolues = element("affaires.suivi.résolu", dans: app)
        XCTAssertTrue(resolues.apparait())
        if !resolues.isHittable { element("affaires.suivi.toutes", dans: app).swipeLeft() }
        resolues.tap()
        XCTAssertTrue(element("affaires.carte.A-0031", dans: app).apparait())
        XCTAssertFalse(element("affaires.carte.A-0041", dans: app).exists, "une affaire chez le syndic sort")
        XCTAssertFalse(element("affaires.carte.A-0022", dans: app).exists, "une résolue archivée reste aux Archives")
    }
}
