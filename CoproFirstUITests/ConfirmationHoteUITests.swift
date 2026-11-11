// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// La confirmation d'un hôte jamais vu, avant le premier mot de passe (#82), contre
/// l'API simulée : `tilleuls.exemple.fr` sert la preuve, `imitation.exemple.fr` non.
final class ConfirmationHoteUITests: XCTestCase {
    @MainActor
    func testUnHoteJamaisVuSeConfirmeAvantLeMotDePasse() throws {
        let app = LancementCaptures.lancer(ecran: "connexion")
        saisirIdentifiants(app)

        let hote = app.elementAcces("confirmationHote.hote")
        XCTAssertTrue(hote.waitForExistence(timeout: 5), "l'écran de confirmation s'ouvre")
        XCTAssertEqual(hote.label, "tilleuls.exemple.fr", "l'hôte en entier")
        XCTAssertFalse(app.buttons["faceid.plusTard"].exists, "rien ne s'est ouvert : le mot de passe attend")
        XCTAssertTrue(app.elementAcces("confirmationHote.reconnue").waitForExistence(timeout: 5), "la preuve lue")
        LancementCaptures.capturer("confirmation-hote-1-reconnue")

        Self.confirmer(app)
        XCTAssertTrue(app.buttons["faceid.plusTard"].waitForExistence(timeout: 5), "la connexion part après l'accord")
    }

    @MainActor
    func testSansPreuveUnSecondAccordEstDemande() throws {
        // Depuis l'accueil : le champ de la résidence est vide, l'adresse s'y tape entière.
        let app = LancementCaptures.lancer(ecran: "accueil")
        app.elementAcces("accueil.entrer").tap()
        let residence = app.elementAcces("connexion.residence")
        XCTAssertTrue(residence.waitForExistence(timeout: 5))
        residence.tap()
        residence.typeText("imitation.exemple.fr")
        XCTAssertTrue(app.staticTexts["Résidence Les Tilleuls"].waitForExistence(timeout: 5), "l'imitation répond")
        saisirIdentifiants(app)

        XCTAssertTrue(
            app.elementAcces("confirmationHote.avertissement").waitForExistence(timeout: 5), "l'avertissement en clair")
        XCTAssertEqual(app.elementAcces("confirmationHote.hote").label, "imitation.exemple.fr")
        XCTAssertTrue(Self.etat(app, "confirmationHote.confirmer", actif: false), "un seul accord ne suffit pas")
        LancementCaptures.capturer("confirmation-hote-2-avertissement")

        // Le libellé donne l'accord, comme l'interrupteur — au grand texte, l'écran défile jusqu'à lui.
        app.elementAcces("confirmationHote.secondAccord").tap()
        XCTAssertTrue(Self.etat(app, "confirmationHote.confirmer", actif: true), "le second accord ouvre la connexion")
        LancementCaptures.capturer("confirmation-hote-3-second-accord")
        app.elementAcces("confirmationHote.confirmer").tap()
        XCTAssertTrue(app.buttons["faceid.plusTard"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAnnulerNEnvoieRien() throws {
        let app = LancementCaptures.lancer(ecran: "connexion")
        saisirIdentifiants(app)
        let annuler = app.elementAcces("confirmationHote.annuler")
        XCTAssertTrue(annuler.waitForExistence(timeout: 5))
        annuler.tap()
        XCTAssertTrue(app.elementAcces("connexion.valider").waitForExistence(timeout: 3), "retour à la connexion")
        XCTAssertFalse(app.buttons["faceid.plusTard"].waitForExistence(timeout: 2), "rien ne s'est ouvert")
    }

    /// « Me connecter à cette adresse », une fois la preuve lue — pour les tests qui
    /// passent par une première connexion.
    @MainActor
    static func confirmer(_ app: XCUIApplication) {
        XCTAssertTrue(etat(app, "confirmationHote.confirmer", actif: true), "la preuve est lue")
        app.elementAcces("confirmationHote.confirmer").tap()
    }

    /// L'état d'un bouton. Un conteneur qui porte l'identifiant est toujours actif : seul
    /// l'élément INACTIF fait foi — présent, le bouton est inactif ; disparu, il est actif.
    @MainActor
    static func etat(_ app: XCUIApplication, _ identifiant: String, actif: Bool) -> Bool {
        let inactif = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND isEnabled == false", identifiant)).firstMatch
        guard actif else { return inactif.waitForExistence(timeout: 5) }
        XCTAssertTrue(app.elementAcces(identifiant).waitForExistence(timeout: 5))
        return inactif.waitForNonExistence(timeout: 5)
    }

    @MainActor
    private func saisirIdentifiants(_ app: XCUIApplication) {
        let email = app.elementAcces("connexion.email")
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("resident@exemple.fr\n")
        app.elementAcces("connexion.motDePasse").typeText("secret\n")
    }
}
