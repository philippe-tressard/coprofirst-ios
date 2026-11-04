// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Communauté, FAQ, Profil et Notifications (#14), contre l'API simulée. Avec la
/// variable `TEST_RUNNER_CAPTURES=<dossier>`, chaque étape y laisse sa capture ;
/// `TEST_RUNNER_THEME=sombre` et `TEST_RUNNER_GRAND_TEXTE=1` en changent le rendu.
final class CommunauteUITests: XCTestCase {
    private let environnement = ProcessInfo.processInfo.environment

    private func lancer() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil"]
        // Le thème choisi au Profil se lit dans les réglages : l'argument le pose.
        app.launchArguments += ["-theme", environnement["THEME"] ?? "auto"]
        if environnement["GRAND_TEXTE"] != nil {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    /// Une capture, quand un dossier est demandé ; rien sinon.
    private func capture(_ nom: String) {
        guard let dossier = environnement["CAPTURES"] else { return }
        let suffixe = [environnement["THEME"], environnement["GRAND_TEXTE"] != nil ? "grand-texte" : nil]
            .compactMap { $0 }.joined(separator: "-")
        let fichier = URL(fileURLWithPath: dossier)
            .appendingPathComponent(nom + (suffixe.isEmpty ? "" : "-" + suffixe) + ".png")
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: fichier)
    }

    /// Le libellé ou la valeur de l'élément contient-il `texte`, d'ici `delai` secondes ?
    private func lu(_ element: XCUIElement, contient texte: String, delai: TimeInterval = 8) -> Bool {
        let fin = Date().addingTimeInterval(delai)
        repeat {
            if "\(element.label) \(element.value ?? "")".contains(texte) { return true }
            Thread.sleep(forTimeInterval: 0.3)
        } while Date() < fin
        return false
    }

    /// L'élément, ramené à l'écran : en très grand texte, il faut souvent défiler.
    @discardableResult
    private func atteindre(_ app: XCUIApplication, _ element: XCUIElement) -> XCUIElement {
        _ = element.waitForExistence(timeout: 8)
        var essais = 0
        while !(element.exists && element.isHittable), essais < 8 {
            app.swipeUp()
            essais += 1
        }
        return element
    }

    private func ouvrirDansPlus(_ app: XCUIApplication, _ libelle: String) {
        let plus = app.tabBars.buttons["Plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 8))
        plus.tap()
        let ligne = atteindre(app, app.buttons[libelle].firstMatch)
        XCTAssertTrue(ligne.exists, "« \(libelle) » dans Plus")
        ligne.tap()
    }

    @MainActor
    func testLaCommunauteSOuvreEtUneIdeeSeSoutient() throws {
        let app = lancer()
        ouvrirDansPlus(app, "Communauté")
        XCTAssertTrue(app.buttons["sondage.12"].waitForExistence(timeout: 8))
        capture("1-communaute-sondages")

        app.segmentedControls["communaute.onglets"].buttons.element(boundBy: 1).tap()
        let coeur = atteindre(app, app.buttons["idee.5.voter"])
        XCTAssertTrue(coeur.exists)
        XCTAssertEqual(coeur.label, "Voter pour cette idée")
        coeur.tap()
        XCTAssertTrue(
            app.buttons["Retirer mon vote"].waitForExistence(timeout: 5), "le cœur se remplit, le vote se voit")
        capture("2-communaute-idees")

        atteindre(app, app.buttons["idee.3"]).tap()
        XCTAssertTrue(atteindre(app, app.staticTexts["Excellente idée, je veux bien m'en occuper."]).exists)
        capture("3-idee-et-reponses")
        app.navigationBars.buttons.firstMatch.tap()

        app.segmentedControls["communaute.onglets"].buttons.element(boundBy: 2).tap()
        let annonce = atteindre(app, app.buttons["annonce.21"])
        XCTAssertTrue(annonce.exists)
        capture("4-communaute-annonces")
        annonce.tap()
        XCTAssertTrue(atteindre(app, app.links["Voisine du 2ᵉ"]).exists, "le contact est un lien")
        capture("5-annonce")
        app.navigationBars.buttons.firstMatch.tap()

        app.segmentedControls["communaute.onglets"].buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.descendants(matching: .any)["avis.4"].waitForExistence(timeout: 8))
        capture("6-communaute-avis")
        app.buttons["communaute.creer"].tap()
        XCTAssertTrue(app.navigationBars["Donner mon avis"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["formulaire.enregistrer"].isEnabled, "rien n'est saisi : le bouton attend")
        capture("7-donner-mon-avis")
    }

    @MainActor
    func testLaClocheOuvreLesNotificationsEtToutSeMarqueLu() throws {
        let app = lancer()
        let cloche = app.buttons["cloche"].firstMatch
        XCTAssertTrue(cloche.waitForExistence(timeout: 8))
        // VoiceOver lit le nombre : dans la valeur, ou dans la pastille que la barre d'iOS 26 y ajoute.
        XCTAssertTrue(
            lu(cloche, contient: "2"), "la cloche dit 2 non lues — lu : \(cloche.label) / \(cloche.value ?? "")")
        cloche.tap()
        let tout = app.buttons["notifications.toutMarquerLu"]
        XCTAssertTrue(tout.waitForExistence(timeout: 8))
        capture("8-notifications")
        tout.tap()
        XCTAssertTrue(tout.waitForNonExistence(timeout: 5), "plus rien à marquer")
        app.buttons["OK"].tap()
        XCTAssertFalse(lu(app.buttons["cloche"].firstMatch, contient: "2", delai: 3), "la cloche n'a plus de pastille")
    }

    @MainActor
    func testLaFAQEtLeProfilSOuvrent() throws {
        let app = lancer()
        ouvrirDansPlus(app, "FAQ")
        let question = atteindre(app, app.descendants(matching: .any)["faq.2"])
        XCTAssertTrue(question.exists)
        question.tap()
        let reponse = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Pas de gravats"))
        XCTAssertTrue(atteindre(app, reponse.firstMatch).exists, "la réponse s'est dépliée")
        capture("9-faq")
        app.navigationBars.buttons.firstMatch.tap()

        atteindre(app, app.buttons["Profil"].firstMatch).tap()
        XCTAssertTrue(atteindre(app, app.staticTexts["resident@exemple.fr"]).exists)
        capture("10-profil")
        let sombre = atteindre(app, app.segmentedControls["profil.theme"].buttons["Sombre"])
        XCTAssertTrue(sombre.exists)
        sombre.tap()
        XCTAssertTrue(sombre.isSelected, "le thème choisi est retenu")
        capture("11-profil-theme-sombre")
    }
}
