// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// L'Espace conseil syndical (#15), contre l'API simulée (un compte du conseil) : il
/// s'ouvre depuis « Plus », ses onglets suivent le site, et les trois premiers
/// fonctionnent — approuver un compte, accepter une commande, chercher un badge, ouvrir
/// une fiche de l'annuaire. Recherche par identifiant, jamais par type (`AccesUITests`).
/// Captures et rendus : `LancementCaptures`.
final class EspaceCSUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLesTroisOngletsDuConseil() throws {
        let app = LancementCaptures.lancer()
        let plus = app.descendants(matching: .any)["Plus"].firstMatch
        XCTAssertTrue(plus.waitForExistence(timeout: 8))
        plus.tap()
        app.libelleAcces("Espace CS").tap()

        // Le cadre : les six onglets du site, dans son ordre.
        let validations = app.elementAcces("onglet.validations")
        XCTAssertTrue(validations.waitForExistence(timeout: 5), "la barre d'onglets")
        for id in ["badges", "reporting", "annonces-hall", "annuaire", "courriels"] {
            XCTAssertTrue(app.elementAcces("onglet.\(id)").exists, "l'onglet \(id)")
        }

        // Comptes & accès : approuver un compte, en nouvel arrivant.
        let compte = app.elementAcces("cs.compte.501")
        XCTAssertTrue(compte.waitForExistence(timeout: 5), "la file des comptes")
        XCTAssertTrue(app.elementAcces("cs.compteur.comptes").exists)
        LancementCaptures.capturer("cs-1-comptes-et-acces")
        app.elementAcces("cs.compte.501.approuver").tap()
        let nouvelArrivant = app.elementAcces("cs.validation.nouvel-arrivant")
        XCTAssertTrue(nouvelArrivant.waitForExistence(timeout: 3), "la feuille d'approbation")
        // L'interrupteur, à droite de la ligne : toucher son libellé ne le bascule pas.
        nouvelArrivant.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        LancementCaptures.capturer("cs-2-approuver-nouvel-arrivant")
        app.elementAcces("cs.validation.enregistrer").tap()
        XCTAssertTrue(compte.waitForNonExistence(timeout: 5), "le compte quitte la file")
        accepterUneCommande(app)
        chercherUnBadge(app)
        ouvrirLAnnuaire(app)
    }

    /// Une commande : acceptée avec le code du badge remis.
    @MainActor
    private func accepterUneCommande(_ app: XCUIApplication) {
        // Une commande : acceptée avec le code du badge remis.
        let commande = app.elementAcces("cs.commande.71")
        let accepter = app.elementAcces("cs.commande.71.approuver")
        for _ in 0..<8 where !accepter.isHittable { app.swipeUp() }
        accepter.tap()
        // Le champ d'une alerte ne garde pas son identifiant : il se trouve par son indication.
        let codes = app.descendants(matching: .any)
            .matching(NSPredicate(format: "placeholderValue == %@", "4521, 417D5927")).firstMatch
        XCTAssertTrue(codes.waitForExistence(timeout: 3), "les codes remis")
        codes.typeText("4521")
        app.descendants(matching: .any)["Accepter"].firstMatch.tap()
        XCTAssertTrue(commande.waitForNonExistence(timeout: 5), "la commande quitte la file")
    }

    @MainActor
    private func chercherUnBadge(_ app: XCUIApplication) {
        // Badges & télécommandes : la recherche filtre, sans accents.
        app.elementAcces("onglet.badges").tap()
        let badge = app.elementAcces("cs.badge.vigik-1")
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "le parc")
        LancementCaptures.capturer("cs-3-badges")
        let recherche = app.elementAcces("cs.badges.recherche")
        recherche.tap()
        recherche.typeText("celeste")
        XCTAssertTrue(app.elementAcces("cs.badge.vigik-4").waitForExistence(timeout: 3))
        XCTAssertFalse(badge.exists, "la recherche filtre")
    }

    @MainActor
    private func ouvrirLAnnuaire(_ app: XCUIApplication) {
        // Annuaire CS & Syndic : les fiches, l'en-tête du conseil en feuille.
        app.elementAcces("onglet.annuaire").tap()
        XCTAssertTrue(app.elementAcces("cs.annuaire.conseil.0").waitForExistence(timeout: 5), "le conseil")
        LancementCaptures.capturer("cs-4-annuaire-conseil")
        app.elementAcces("cs.annuaire.conseil.modifier").tap()
        XCTAssertTrue(app.elementAcces("cs.feuille.entete-conseil").waitForExistence(timeout: 3), "l'en-tête")
        LancementCaptures.capturer("cs-5-annuaire-entete")
        app.descendants(matching: .any)["Annuler"].firstMatch.tap()
        let syndic = app.elementAcces("cs.annuaire.syndic.0")
        XCTAssertTrue(syndic.waitForExistence(timeout: 5), "le syndic")
        for _ in 0..<8 where !syndic.isHittable { app.swipeUp() }
        LancementCaptures.capturer("cs-6-annuaire-syndic")
    }
}
