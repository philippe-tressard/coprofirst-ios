// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Le parcours v2, contre l'API simulée : aucune requête ne part.
final class ParcoursUITests: XCTestCase {
    @MainActor
    func testDeLAccueilAuFilParLaConnexion() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee"]
        app.launch()

        app.buttons["accueil.entrer"].tap()
        let residence = app.textFields["connexion.residence"]
        XCTAssertTrue(residence.waitForExistence(timeout: 5))
        residence.tap()
        residence.typeText("inconnue.exemple.fr")
        XCTAssertTrue(
            app.staticTexts[
                "Cette adresse répond, mais aucune résidence n'y est installée. "
                    + "Vérifiez-la sur votre fiche d'arrivée."
            ].waitForExistence(timeout: 5),
            "un hôte inconnu (421) se dit en une phrase")

        residence.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + "ancienne.exemple.fr")
        XCTAssertTrue(
            app.staticTexts[
                "Cette résidence doit être mise à jour pour s'ouvrir dans l'app. Prévenez son administrateur."
            ].waitForExistence(timeout: 5),
            "une résidence sous le plancher le dit (#83)")

        residence.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + "tilleuls.exemple.fr")
        XCTAssertTrue(app.staticTexts["Résidence Les Tilleuls"].waitForExistence(timeout: 5), "reconnue")

        let email = app.textFields["connexion.email"]
        email.tap()
        email.typeText("resident@exemple.fr\n")
        let motDePasse = app.secureTextFields["connexion.motDePasse"]
        motDePasse.typeText("refuse\n")
        // Saisie à la main, jamais vue : l'adresse se confirme avant le mot de passe (#82).
        ConfirmationHoteUITests.confirmer(app)
        XCTAssertTrue(app.staticTexts["Adresse électronique ou mot de passe incorrect."].waitForExistence(timeout: 5))

        email.tap()
        email.typeText("\n")
        motDePasse.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10) + "secret\n")

        let plusTard = app.buttons["faceid.plusTard"]
        XCTAssertTrue(plusTard.waitForExistence(timeout: 5), "Face ID proposé après la 1ʳᵉ connexion")
        plusTard.tap()
        XCTAssertTrue(app.staticTexts["Fuite d'eau au plafond du parking"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pastille.residence"].exists)
    }

    @MainActor
    func testLaDemoSOuvreDUnToucher() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee"]
        app.launch()

        app.buttons["accueil.demo"].tap()
        let conseil = app.buttons["demo.user-cs"]
        XCTAssertTrue(conseil.waitForExistence(timeout: 5))
        conseil.tap()
        XCTAssertTrue(app.staticTexts["Fuite d'eau au plafond du parking"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaBarreAfficheLesLibellesCourts() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil"]
        app.launch()
        let barre = app.tabBars.firstMatch
        XCTAssertTrue(barre.waitForExistence(timeout: 5))
        for libelle in ["Fil d'activité", "Résidence", "Affaires", "Accès", "Plus"] {
            XCTAssertTrue(barre.buttons[libelle].exists, "« \(libelle) » dans la barre")
        }
        XCTAssertFalse(barre.buttons["Mes lots & accès"].exists)
        barre.buttons["Accès"].tap()
        XCTAssertTrue(app.navigationBars["Mes lots & accès"].waitForExistence(timeout: 3), "l'écran garde son titre")
    }

    @MainActor
    func testUnePageRenommeeGardeSonNomDansLaBarre() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil", "-page-renommee"]
        app.launch()
        let barre = app.tabBars.firstMatch
        XCTAssertTrue(barre.waitForExistence(timeout: 5))
        XCTAssertTrue(barre.buttons["Clés et badges"].exists)
        XCTAssertFalse(barre.buttons["Accès"].exists)
    }

    @MainActor
    func testLaPastilleMontreLesRolesEtSeDeconnecte() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil"]
        app.launch()
        let logement = app.buttons["fil.lot"]
        XCTAssertTrue(logement.waitForExistence(timeout: 5), "le logement en haut à gauche, dans la barre")
        XCTAssertLessThan(logement.frame.maxX, app.buttons["pastille.residence"].frame.minX, "à gauche de la résidence")

        app.buttons["pastille.residence"].tap()
        let roles = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Conseil syndical")).firstMatch
        XCTAssertTrue(roles.waitForExistence(timeout: 5), "les rôles de la résidence")

        app.buttons["residence.deconnecter"].tap()
        // La feuille d'action expose son bouton deux fois (feuille et menu) : le premier.
        let confirmer = app.buttons["sortie.confirmer"].firstMatch
        XCTAssertTrue(confirmer.waitForExistence(timeout: 3), "le geste se confirme")
        confirmer.tap()

        let adresse = app.textFields["connexion.residence"]
        XCTAssertTrue(adresse.waitForExistence(timeout: 5), "retour à la connexion")
        XCTAssertEqual(adresse.value as? String, "tilleuls.exemple.fr", "adresse pré-remplie")
        XCTAssertFalse(app.tabBars.firstMatch.exists, "le fil n'est plus affiché")
    }

    /// Un libellé de logement trop long se tronque : la pastille de la résidence reste
    /// dans la barre (avant, iOS la repliait dans un menu « … »).
    @MainActor
    func testUnLogementLongNeChassePasLaResidence() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil", "-logement-long"]
        app.launch()
        let logement = app.buttons["fil.lot"]
        XCTAssertTrue(logement.waitForExistence(timeout: 5))
        let residence = app.buttons["pastille.residence"]
        XCTAssertTrue(residence.waitForExistence(timeout: 3) && residence.isHittable, "la résidence reste visible")
        XCTAssertTrue(app.buttons["cloche"].isHittable, "la cloche aussi")
        XCTAssertLessThan(logement.frame.maxX, residence.frame.minX)

        logement.tap()
        // Le geste ouvre Mes lots & accès : l'onglet est retenu (attendu, la barre s'anime).
        expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: app.tabBars.buttons["Accès"])
        waitForExpectations(timeout: 3)
    }

    /// Aux tailles d'accessibilité, le logement redescend sous le titre : dans la barre,
    /// iOS y coincerait le titre entre les deux côtés.
    @MainActor
    func testEnTresGrandTexteLeLogementPasseSousLeTitre() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-api-simulee", "-ecran", "fil", "-logement-long",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        let logement = app.buttons["fil.lot"]
        XCTAssertTrue(logement.waitForExistence(timeout: 5))
        let residence = app.buttons["pastille.residence"]
        XCTAssertTrue(residence.waitForExistence(timeout: 3) && residence.isHittable)
        XCTAssertGreaterThan(logement.frame.minY, residence.frame.maxY, "sous la barre, pas dedans")
    }
}
