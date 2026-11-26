// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// La connexion d'un seul toucher (#47), contre l'API simulée : aucune requête ne part.
final class ConnexionUITests: XCTestCase {
    /// Clavier levé sur le mot de passe, le bouton « Se connecter » était SOUS le
    /// clavier : le premier toucher tombait sur le clavier, `seConnecter()` ne partait pas.
    @MainActor
    func testUnSeulToucherSurSeConnecterOuvreLaResidence() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "connexion"]
        app.launch()

        let email = app.textFields["connexion.email"]
        app.toucher(email)
        email.typeText("resident@example.com")
        let motDePasse = app.secureTextFields["connexion.motDePasse"]
        app.toucher(motDePasse)
        motDePasse.typeText("secret")

        // Le champ mot de passe a le focus : le bouton doit se voir au-dessus du clavier.
        let valider = app.buttons["connexion.valider"]
        XCTAssertTrue(valider.attendre("isHittable == true"), "le bouton se voit au-dessus du clavier")

        // Un toucher là où le bouton est dessiné, comme un doigt, une fois le clavier posé.
        app.toucherAuDessin(valider)
        // Un hôte jamais vu sur cet appareil : l'adresse se confirme d'abord (#82).
        ConfirmationHoteUITests.confirmer(app)

        XCTAssertTrue(
            app.buttons["faceid.plusTard"].apparait(),
            "la résidence s'ouvre dès la réponse du serveur, sans second toucher")
        XCTAssertFalse(valider.exists, "l'écran de connexion n'est plus affiché")
    }

    /// Un compte au mot de passe temporaire (#377) : rien d'autre ne s'ouvre avant d'en
    /// choisir un ; choisi, le compte relu ouvre la résidence.
    @MainActor
    func testUnMotDePasseTemporaireSeChoisitAvantTout() throws {
        let app = LancementCaptures.lancer(arguments: ["-compte", "temporaire"])
        let actuel = app.secureTextFields["motDePasse.actuel"]
        XCTAssertTrue(actuel.apparait(), "« Choisir votre mot de passe », seul")
        // La pastille de la résidence, en tête du Fil : sur iPhone comme sur iPad, où la barre
        // latérale n'a pas de « Plus ».
        let residence = app.buttons["pastille.residence"]
        XCTAssertFalse(residence.exists, "la résidence ne s'ouvre pas encore")
        XCTAssertTrue(app.buttons["residence.deconnecter"].exists, "la déconnexion reste offerte")

        app.toucher(actuel)
        actuel.typeText("temporaire1")
        let nouveau = app.secureTextFields["motDePasse.nouveau"]
        app.toucher(nouveau)
        nouveau.typeText("choisi-2026")
        let confirmation = app.secureTextFields["motDePasse.confirmation"]
        app.toucher(confirmation)
        confirmation.typeText("choisi-2026")
        app.toucher(app.buttons["motDePasse.valider"], jusqua: residence)
        XCTAssertFalse(actuel.exists, "la porte se lève : la résidence s'ouvre")
    }

    /// La connexion FRAÎCHE d'un compte temporaire (#405) : le compte se lit avant que la
    /// résidence s'ouvre — la porte vient seule, jamais le Fil refusé avant elle.
    @MainActor
    func testUneConnexionFraicheMeneDroitALaPorteDuMotDePasseTemporaire() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "connexion", "-compte", "temporaire"]
        app.launch()

        let email = app.textFields["connexion.email"]
        app.toucher(email)
        email.typeText("resident@example.com")
        let motDePasse = app.secureTextFields["connexion.motDePasse"]
        app.toucher(motDePasse)
        motDePasse.typeText("temporaire1")
        app.toucherAuDessin(app.buttons["connexion.valider"])
        ConfirmationHoteUITests.confirmer(app)

        XCTAssertTrue(app.secureTextFields["motDePasse.actuel"].apparait(), "la porte, dès l'ouverture")
        XCTAssertFalse(app.buttons["pastille.residence"].exists, "le Fil ne s'est pas ouvert avant elle")
        XCTAssertFalse(app.buttons["faceid.plusTard"].exists, "Face ID attend que la porte se lève")
    }
}
