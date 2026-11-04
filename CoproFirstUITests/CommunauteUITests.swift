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
    /// Un élément de cet identifiant dit-il `texte` (libellé ou valeur), d'ici `delai` ?
    /// Par prédicat sur TOUS les éléments de l'identifiant : sous iOS 26.5, un bouton de
    /// barre d'outils est enveloppé dans un conteneur de même identifiant, que
    /// `firstMatch` rendrait — sans le libellé ni la valeur du bouton.
    private func lu(_ app: XCUIApplication, _ identifiant: String, contient texte: String, delai: TimeInterval = 8)
        -> Bool {
        let predicat = NSPredicate(
            format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)", identifiant, texte, texte)
        return app.descendants(matching: .any).matching(predicat).firstMatch.waitForExistence(timeout: delai)
    }

    /// Un élément de cet identifiant est-il inactif ? (Le conteneur, lui, l'est toujours.)
    private func inactif(_ app: XCUIApplication, _ identifiant: String) -> Bool {
        let predicat = NSPredicate(format: "identifier == %@ AND isEnabled == false", identifiant)
        return app.descendants(matching: .any).matching(predicat).firstMatch.waitForExistence(timeout: 3)
    }

    /// Un élément par son identifiant (ou son libellé), QUEL QUE SOIT SON TYPE : un `Link`
    /// n'a pas le même type d'accessibilité sous iOS 26 (CI) et 27 (poste).
    private func el(_ app: XCUIApplication, _ identifiant: String) -> XCUIElement {
        app.descendants(matching: .any)[identifiant].firstMatch
    }

    /// Le premier élément dont le libellé contient `texte`, quel que soit son type.
    private func texte(_ app: XCUIApplication, _ texte: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", texte)).firstMatch
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

    /// Une rubrique de la Communauté : la barre défile jusqu'à elle (très grand texte).
    private func rubrique(_ app: XCUIApplication, _ id: String) {
        let onglet = el(app, "communaute.onglet.\(id)")
        XCTAssertTrue(onglet.waitForExistence(timeout: 5))
        var essais = 0
        // Hors de l'écran, l'élément n'a pas de point d'activation : on compare les cadres.
        let ecran = app.windows.firstMatch.frame
        while !ecran.contains(onglet.frame), essais < 4 {
            // Un glissé du doigt sur la barre, de droite à gauche, à sa hauteur.
            let origine = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            let depart = origine.withOffset(CGVector(dx: ecran.width * 0.85, dy: onglet.frame.midY))
            depart.press(forDuration: 0.05, thenDragTo: origine.withOffset(
                CGVector(dx: ecran.width * 0.15, dy: onglet.frame.midY)))
            essais += 1
        }
        onglet.tap()
    }

    private func ouvrirDansPlus(_ app: XCUIApplication, _ libelle: String) {
        let plus = app.tabBars.buttons["Plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 8))
        plus.tap()
        let ligne = atteindre(app, el(app, libelle))
        XCTAssertTrue(ligne.exists, "« \(libelle) » dans Plus")
        ligne.tap()
    }

    @MainActor
    func testLaCommunauteSOuvreEtUneIdeeSeSoutient() throws {
        let app = lancer()
        ouvrirDansPlus(app, "Communauté")
        XCTAssertTrue(el(app, "sondage.12").waitForExistence(timeout: 8))
        capture("1-communaute-sondages")

        rubrique(app, "idees")
        let coeur = atteindre(app, el(app, "idee.5.voter"))
        XCTAssertTrue(coeur.exists)
        XCTAssertEqual(coeur.label, "Voter pour cette idée")
        coeur.tap()
        XCTAssertTrue(
            lu(app, "idee.5.voter", contient: "Retirer mon vote", delai: 5), "le cœur se remplit, le vote se voit")
        capture("2-communaute-idees")

        atteindre(app, el(app, "idee.3")).tap()
        XCTAssertTrue(atteindre(app, texte(app, "Excellente idée, je veux bien m'en occuper.")).exists)
        capture("3-idee-et-reponses")
        app.navigationBars.buttons.firstMatch.tap()

        rubrique(app, "annonces")
        let annonce = atteindre(app, el(app, "annonce.21"))
        XCTAssertTrue(annonce.exists)
        capture("4-communaute-annonces")
        annonce.tap()
        XCTAssertTrue(atteindre(app, el(app, "annonce.contact")).exists, "le contact est un lien")
        capture("5-annonce")
        app.navigationBars.buttons.firstMatch.tap()

        rubrique(app, "avis")
        XCTAssertTrue(app.descendants(matching: .any)["avis.4"].waitForExistence(timeout: 8))
        capture("6-communaute-avis")
        el(app, "communaute.creer").tap()
        XCTAssertTrue(app.navigationBars["Donner mon avis"].waitForExistence(timeout: 5))
        XCTAssertTrue(inactif(app, "formulaire.enregistrer"), "rien n'est saisi : le bouton attend")
        capture("7-donner-mon-avis")
    }

    @MainActor
    func testLaClocheOuvreLesNotificationsEtToutSeMarqueLu() throws {
        let app = lancer()
        let cloche = el(app, "cloche")
        XCTAssertTrue(cloche.waitForExistence(timeout: 8))
        // VoiceOver lit le nombre : dans la valeur, ou dans la pastille que la barre d'iOS 26 y ajoute.
        XCTAssertTrue(
            lu(app, "cloche", contient: "2"), "la cloche dit 2 non lues — lu : \(cloche.label) / \(cloche.value ?? "")")
        cloche.tap()
        let tout = el(app, "notifications.toutMarquerLu")
        XCTAssertTrue(tout.waitForExistence(timeout: 8))
        capture("8-notifications")
        tout.tap()
        XCTAssertTrue(tout.waitForNonExistence(timeout: 5), "plus rien à marquer")
        el(app, "notifications.ok").tap()
        XCTAssertFalse(lu(app, "cloche", contient: "2", delai: 3), "la cloche n'a plus de pastille")
    }

    @MainActor
    func testLaFAQEtLeProfilSOuvrent() throws {
        let app = lancer()
        ouvrirDansPlus(app, "FAQ")
        let question = atteindre(app, app.descendants(matching: .any)["faq.2"])
        XCTAssertTrue(question.exists)
        question.tap()
        let reponse = texte(app, "Pas de gravats")
        XCTAssertTrue(atteindre(app, reponse).exists, "la réponse s'est dépliée")
        capture("9-faq")
        app.navigationBars.buttons.firstMatch.tap()

        atteindre(app, el(app, "plus.profil")).tap()
        XCTAssertTrue(atteindre(app, texte(app, "resident@exemple.fr")).exists)
        capture("10-profil")
        let sombre = atteindre(app, el(app, "profil.theme").buttons["Sombre"])
        XCTAssertTrue(sombre.exists)
        sombre.tap()
        XCTAssertTrue(sombre.isSelected, "le thème choisi est retenu")
        capture("11-profil-theme-sombre")
    }
}
