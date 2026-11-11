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
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("resident@exemple.fr")
        let motDePasse = app.secureTextFields["connexion.motDePasse"]
        motDePasse.tap()
        motDePasse.typeText("secret")

        // Le champ mot de passe a le focus : le bouton doit se voir au-dessus du clavier.
        let valider = app.buttons["connexion.valider"]
        XCTAssertTrue(valider.attendre("isHittable == true"), "le bouton se voit au-dessus du clavier")

        // Un toucher là où le bouton est dessiné, comme un doigt : sans le défilement
        // qu'XCUITest ajoute de lui-même avant `tap()` sur un élément caché.
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: valider.frame.midX, dy: valider.frame.midY))
            .tap()
        // Un hôte jamais vu sur cet appareil : l'adresse se confirme d'abord (#82).
        ConfirmationHoteUITests.confirmer(app)

        XCTAssertTrue(
            app.buttons["faceid.plusTard"].waitForExistence(timeout: 5),
            "la résidence s'ouvre dès la réponse du serveur, sans second toucher")
        XCTAssertFalse(valider.exists, "l'écran de connexion n'est plus affiché")
    }
}
