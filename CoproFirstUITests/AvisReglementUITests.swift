// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// #71 — l'avis du règlement à renvois (contrat 1.14.0), sur l'API simulée : « Ce qui
/// fonde l'avis » se lit d'emblée, et un fondement ouvre sa section et amène à son
/// extrait. `TEST_RUNNER_CAPTURES`, `TEST_RUNNER_THEME` et `TEST_RUNNER_GRAND_TEXTE`
/// en laissent les captures (`LancementCaptures`).
final class AvisReglementUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testUnFondementOuvreSaSectionEtAmeneASonExtrait() throws {
        let app = LancementCaptures.lancer()
        ouvrirLAvis(app, question: "Puis-je installer une climatisation sur mon balcon ?")

        let fondement = element(app, "avis.fondement.AG1")
        XCTAssertTrue(fondement.apparait(), "les fondements se lisent sans rien déplier")
        XCTAssertFalse(element(app, "avis.extrait.AG1").exists, "les sections sont pliées d'abord")
        LancementCaptures.capturer("avis-renvois")

        fondement.tap()
        let extrait = element(app, "avis.extrait.AG1")
        XCTAssertTrue(extrait.apparait(), "le fondement ouvre la section des AG")
        XCTAssertTrue(extrait.isHittable, "et fait venir l'extrait à l'écran")
        XCTAssertFalse(element(app, "avis.extrait.R1").exists, "une seule section ouverte à la fois")
        LancementCaptures.capturer("avis-renvois-extrait")

        element(app, "avis.section.assemblees").tap()
        XCTAssertTrue(element(app, "avis.extrait.AG1").disparait(), "le bandeau replie sa section")
    }

    @MainActor
    func testUnAvisDAvantSeLitSectionApresSection() throws {
        let app = LancementCaptures.lancer()
        ouvrirLAvis(app, question: "Puis-je poser une jardinière sur le garde-corps ?")
        XCTAssertTrue(app.descendants(matching: .any)["Extraits du règlement"].apparait())
        XCTAssertFalse(element(app, "avis.fondements").exists, "sans renvois, pas de fondements")
        LancementCaptures.capturer("avis-avant")
    }

    @MainActor
    private func ouvrirLAvis(_ app: XCUIApplication, question: String) {
        let barre = app.tabBars.firstMatch
        XCTAssertTrue(barre.apparait())
        barre.descendants(matching: .any)["Résidence"].firstMatch.tap()
        let onglet = app.descendants(matching: .any)["Règlement"].firstMatch
        if !onglet.sonde() {
            // Aux tailles d'accessibilité, les onglets sont un menu (`ResidenceView.choixOnglet`).
            element(app, "residence.onglets").tap()
        }
        XCTAssertTrue(onglet.apparait())
        onglet.tap()
        let carte = app.descendants(matching: .any)[question].firstMatch
        for _ in 0..<4 where !(carte.sonde() && carte.isHittable) {
            app.swipeUp()
        }
        carte.tap()
    }

    private func element(_ app: XCUIApplication, _ identifiant: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifiant).firstMatch
    }
}
