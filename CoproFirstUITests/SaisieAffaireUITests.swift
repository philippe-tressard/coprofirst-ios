// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// « Nouvelle affaire » selon la saisie du compte (#69), contre l'API simulée : en
/// Essentielle (le défaut du serveur), l'urgence d'une question se range dans « Plus de
/// détails », celle d'une panne reste à son rang ; en Complète, tout est à son rang ; le
/// choix se fait au Profil et vaut aussitôt.
///
/// `TEST_RUNNER_CAPTURES=<dossier>` et `TEST_RUNNER_THEME=clair|sombre` : les captures de la PR.
@MainActor
final class SaisieAffaireUITests: XCTestCase {
    private func lancer(_ arguments: [String] = []) -> XCUIApplication {
        let app = LancementCaptures.lancer(ecran: "affaires", arguments: arguments)
        ouvrirAffaires(app)
        return app
    }

    private func ouvrirAffaires(_ app: XCUIApplication) {
        let onglet = app.descendants(matching: .any)["Affaires"].firstMatch
        XCTAssertTrue(onglet.waitForExistence(timeout: 8))
        onglet.tap()
    }

    private func el(_ app: XCUIApplication, _ identifiant: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifiant).firstMatch
    }

    /// Un élément de cet identifiant dit-il `texte` (libellé ou valeur), d'ici 8 s ?
    private func lu(_ app: XCUIApplication, _ identifiant: String, contient texte: String) -> Bool {
        let predicat = NSPredicate(
            format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)", identifiant, texte, texte)
        return app.descendants(matching: .any).matching(predicat).firstMatch.waitForExistence(timeout: 8)
    }

    /// L'élément ramené à l'écran ; `false` s'il n'y paraît pas. Un `Form` ne crée pas les
    /// lignes hors de l'écran : on défile tant qu'il n'est pas là, pas seulement tant qu'il est caché.
    @discardableResult
    private func atteindre(_ app: XCUIApplication, _ element: XCUIElement) -> Bool {
        // sonde courte : un Form ne crée pas la ligne hors de l'écran, on défile ensuite
        _ = element.waitForExistence(timeout: 3)
        var essais = 0
        while !(element.exists && element.isHittable), essais < 8 {
            app.swipeUp()
            essais += 1
        }
        return element.exists
    }

    private func nouvelle(_ app: XCUIApplication, categorie: String) {
        el(app, "affaires.nouvelle").tap()
        let vignette = el(app, "nouvelle.categorie.\(categorie)")
        XCTAssertTrue(vignette.waitForExistence(timeout: 8))
        vignette.tap()
    }

    func testEnEssentielleLUrgenceDUneQuestionSeRange() throws {
        let app = lancer()
        nouvelle(app, categorie: "question")
        XCTAssertTrue(lu(app, "nouvelle.modeSaisie", contient: "Saisie essentielle"), "la phrase dit la saisie")
        XCTAssertTrue(atteindre(app, el(app, "nouvelle.plusDeDetails")), "l'urgence d'une question est rangée")
        XCTAssertFalse(el(app, "nouvelle.urgente").exists, "plié, le groupe ne montre pas l'urgence")
        LancementCaptures.capturer("saisie-1-essentielle-question")
        el(app, "nouvelle.plusDeDetails").tap()
        XCTAssertTrue(atteindre(app, el(app, "nouvelle.urgente")), "déplié, l'urgence se règle")
        LancementCaptures.capturer("saisie-2-plus-de-details")

        app.swipeDown()
        let panne = el(app, "nouvelle.categorie.panne")
        XCTAssertTrue(panne.waitForExistence(timeout: 5))
        panne.tap()
        XCTAssertTrue(atteindre(app, el(app, "nouvelle.urgente")), "l'urgence d'une panne est essentielle")
        XCTAssertFalse(el(app, "nouvelle.plusDeDetails").exists, "plus rien à ranger : pas de groupe")
        LancementCaptures.capturer("saisie-3-essentielle-panne")
    }

    func testEnCompleteToutEstASonRang() throws {
        let app = lancer(["-saisie", "complete"])
        nouvelle(app, categorie: "question")
        XCTAssertTrue(lu(app, "nouvelle.modeSaisie", contient: "Saisie complète"))
        XCTAssertTrue(atteindre(app, el(app, "nouvelle.urgente")), "en Complète, l'urgence est à son rang")
        XCTAssertFalse(el(app, "nouvelle.plusDeDetails").exists)
        LancementCaptures.capturer("saisie-4-complete")
    }

    func testLeChoixDuProfilVautAussitot() throws {
        let app = lancer()
        let plus = app.tabBars.buttons["Plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 8))
        plus.tap()
        let profil = el(app, "plus.profil")
        XCTAssertTrue(atteindre(app, profil))
        profil.tap()
        let complete = el(app, "profil.saisie").buttons["Complète"]
        XCTAssertTrue(atteindre(app, complete), "le réglage est au Profil")
        XCTAssertTrue(el(app, "profil.saisie").buttons["Essentielle"].isSelected, "le défaut servi est coché")
        LancementCaptures.capturer("saisie-5-profil")
        complete.tap()
        XCTAssertTrue(complete.isSelected, "le choix est retenu")

        ouvrirAffaires(app)
        nouvelle(app, categorie: "question")
        XCTAssertTrue(lu(app, "nouvelle.modeSaisie", contient: "Saisie complète"), "la feuille suit le Profil")
        XCTAssertTrue(atteindre(app, el(app, "nouvelle.urgente")))
    }
}
