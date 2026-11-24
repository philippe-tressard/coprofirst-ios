// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Ma résidence et l'Annuaire (#12), sur l'API simulée (un compte du conseil syndical).
final class ResidenceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLesTroisOngletsDeLaResidence() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil"]
        app.launch()

        app.toucher(app.tabBars.buttons["Résidence"])
        XCTAssertTrue(app.staticTexts["AA0-000-000"].apparait(), "la Fiche s'ouvre d'abord")

        // Trouvés par leur libellé : nommés `onglet…`, lus comme des onglets (#334).
        let ongletCarnet = app.buttons["Carnet d’entretien"]
        app.toucher(ongletCarnet, jusqua: app.staticTexts["Révision annuelle de la chaudière"])
        // Un contrat pas encore commencé : « À venir » dans la gouttière, dit avec sa date (#259).
        let aVenir = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ENDSWITH %@", ", À venir")).firstMatch
        XCTAssertTrue(aVenir.apparait(), "la gouttière du contrat à venir")

        let ongletReglement = app.buttons["Règlement"]
        app.toucher(ongletReglement, jusqua: app.staticTexts["Puis-je installer une climatisation sur mon balcon ?"])
        XCTAssertFalse(app.buttons["reglement.poser"].isEnabled, "question vide : rien à poser")
    }

    @MainActor
    func testLeSyndicDeLaFicheOuvreLAnnuaire() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil"]
        app.launch()

        app.tabBars.buttons["Résidence"].tap()
        let syndic = app.descendants(matching: .any).matching(identifier: "residence.syndic").firstMatch
        XCTAssertTrue(syndic.apparait())
        syndic.tap()
        XCTAssertTrue(app.staticTexts["Gestionnaire de copropriété"].apparait())
        // Par l'identifiant, pas par le type : un `Link` est un lien sous iOS 27, pas sous iOS 26.
        let appeler = app.descendants(matching: .any).matching(identifier: "annuaire.appeler")
            .matching(NSPredicate(format: "label CONTAINS '01 00 00 00 01'")).firstMatch
        XCTAssertTrue(appeler.apparait())
    }
}
