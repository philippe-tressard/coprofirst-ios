// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// « Mes lots & accès » (#13), sur l'API simulée : chaque onglet s'ouvre, et les
/// gestes d'accès aboutissent. Chaque étape joint sa capture (gardée dans le
/// résultat du test : ce sont les captures de la PR).
///
/// ⚠️ Un élément se cherche par son IDENTIFIANT ou son libellé, jamais par son type
/// (`app.buttons`, `app.links`…) : le type d'accessibilité diffère d'une version
/// d'iOS à l'autre (poste en iOS 27, CI en iOS 26 — leçon de #12).
final class AccesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func ouvrirAcces() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil"]
        app.launch()
        let barre = app.tabBars.firstMatch
        XCTAssertTrue(barre.waitForExistence(timeout: 5))
        barre.buttons["Accès"].tap()
        XCTAssertTrue(app.navigationBars["Mes lots & accès"].waitForExistence(timeout: 3))
        return app
    }

    @MainActor
    func testLesQuatreOngletsSOuvrent() throws {
        let app = ouvrirAcces()
        XCTAssertTrue(app.libelleAcces("Caractéristiques").waitForExistence(timeout: 5), "la carte du lot")
        app.capturerAcces("acces-1-mes-lots", dans: self)

        app.elementAcces("acces.lot.417").tap()
        XCTAssertTrue(app.libelleAcces("Sous-sol A").waitForExistence(timeout: 3), "le lot choisi s'affiche")

        app.elementAcces("onglet.badges").tap()
        XCTAssertTrue(app.libelleAcces("A4F21C07").waitForExistence(timeout: 5), "les badges détenus")
        app.capturerAcces("acces-2-badges", dans: self)

        app.elementAcces("onglet.telecommandes").tap()
        XCTAssertTrue(app.libelleAcces("TC-2048").waitForExistence(timeout: 5), "les télécommandes détenues")
        app.capturerAcces("acces-3-telecommandes", dans: self)

        // Le compte simulé est au conseil syndical : la gestion locative lui est ouverte.
        app.elementAcces("onglet.telecommandes").swipeLeft()
        app.elementAcces("onglet.location").tap()
        XCTAssertTrue(app.libelleAcces("Locataire DU LOT 31").waitForExistence(timeout: 5), "un bail actif")
        app.capturerAcces("acces-4-gestion-locative", dans: self)
        app.libelleAcces("📁 Archives").tap()
        XCTAssertTrue(app.libelleAcces("Ancien locataire DU LOT 31").waitForExistence(timeout: 3), "les archives")
    }

    @MainActor
    func testSignalerPerduPuisDeclarer() throws {
        let app = ouvrirAcces()
        app.elementAcces("onglet.badges").tap()
        let perdu = app.elementAcces("acces.perdu.12")
        XCTAssertTrue(perdu.waitForExistence(timeout: 5))
        perdu.tap()
        app.elementAcces("acces.perdu.confirmer").tap()
        XCTAssertTrue(app.libelleAcces("Signalement enregistré").waitForExistence(timeout: 3))
        XCTAssertFalse(app.elementAcces("acces.perdu.12").exists, "un accès perdu ne se signale plus")

        app.elementAcces("acces.gestes").tap()
        app.elementAcces("acces.geste.declarer").tap()
        let code = app.elementAcces("acces.declarer.code")
        XCTAssertTrue(code.waitForExistence(timeout: 3))
        code.typeText("TC-7777")
        app.capturerAcces("acces-5-declarer", dans: self)
        app.elementAcces("acces.feuille.enregistrer").tap()
        XCTAssertTrue(app.libelleAcces("Accès enregistré").waitForExistence(timeout: 5))
        app.elementAcces("onglet.telecommandes").tap()
        XCTAssertTrue(app.libelleAcces("TC-7777").waitForExistence(timeout: 5), "la liste est relue")
    }

    @MainActor
    func testNouvelAccesNeProposeQueSesLots() throws {
        let app = ouvrirAcces()
        app.elementAcces("onglet.badges").tap()
        app.elementAcces("acces.gestes").tap()
        app.elementAcces("acces.geste.demander").tap()
        XCTAssertTrue(app.navigationBars["Nouvelle demande d'accès"].waitForExistence(timeout: Attente.plafond))
        app.elementAcces("acces.feuille.enregistrer").tap()
        XCTAssertTrue(app.libelleAcces("Sélectionnez un lot").waitForExistence(timeout: 3), "un lot est exigé")
        app.elementAcces("acces.demande.lot").tap()
        XCTAssertTrue(app.libelleAcces("Lot 15").waitForExistence(timeout: 3))
        XCTAssertTrue(app.libelleAcces("Lot 450").exists)
        app.libelleAcces("Lot 15").tap()
        app.capturerAcces("acces-6-nouvel-acces", dans: self)
        app.elementAcces("acces.feuille.enregistrer").tap()
        XCTAssertTrue(app.libelleAcces("Demande envoyée au conseil syndical").waitForExistence(timeout: 5))
    }
}

/// La recherche des tests d'interface de #13 (Accès, Prestataires) : par identifiant
/// ou par libellé, quel que soit le type de l'élément.
extension XCUIApplication {
    func elementAcces(_ identifiant: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifiant).firstMatch
    }

    /// Le premier élément dont le libellé COMMENCE par ce texte (une carte réunit
    /// souvent plusieurs textes en un seul libellé).
    func libelleAcces(_ debut: String) -> XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", debut)).firstMatch
    }

    @MainActor
    func capturerAcces(_ nom: String, dans test: XCTestCase) {
        let piece = XCTAttachment(screenshot: screenshot())
        piece.name = nom
        piece.lifetime = .keepAlways
        test.add(piece)
    }
}
