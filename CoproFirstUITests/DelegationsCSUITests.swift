// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Les Délégations aidant et trois onglets de l'Espace CS (#15) — Reporting, Annonces
/// Hall, Courriels affaires —, contre l'API simulée (un compte du conseil). Recherche par
/// identifiant, jamais par type (`AccesUITests`). Captures et rendus : `LancementCaptures`.
final class DelegationsCSUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func ouvrir(_ libelle: String, _ app: XCUIApplication) {
        let plus = app.descendants(matching: .any)["Plus"].firstMatch
        XCTAssertTrue(plus.waitForExistence(timeout: 8))
        plus.tap()
        let entree = app.libelleAcces(libelle)
        // Aux grandes tailles, la ligne est sous le pli : la liste ne la crée qu'au défilement.
        _ = entree.waitForExistence(timeout: 3)
        for _ in 0..<6 where !(entree.exists && entree.isHittable) { app.swipeUp() }
        XCTAssertTrue(entree.exists, "« \(libelle) » dans Plus")
        entree.tap()
    }

    @MainActor
    func testLesDelegationsSAcceptentSeRevoquentEtSeCreent() throws {
        let app = LancementCaptures.lancer()
        ouvrir("Délégations", app)

        let accepter = app.elementAcces("delegation.12.accepter")
        XCTAssertTrue(accepter.waitForExistence(timeout: 5), "l'aidant accepte la délégation en attente")
        XCTAssertFalse(app.elementAcces("delegation.8.accepter").exists, "pas celle d'un autre aidant")
        LancementCaptures.capturer("delegations-1-liste")
        accepter.tap()
        XCTAssertTrue(accepter.waitForNonExistence(timeout: 5), "acceptée, elle n'attend plus")

        // Révoquer demande une confirmation.
        app.elementAcces("delegation.8.revoquer").tap()
        let confirmer = app.elementAcces("delegations.revoquer.confirmer")
        XCTAssertTrue(confirmer.waitForExistence(timeout: 3), "la confirmation")
        confirmer.tap()
        XCTAssertTrue(app.elementAcces("delegation.8.revoquer").waitForNonExistence(timeout: 5), "révoquée")

        // Nouvelle délégation (conseil) : « Enregistrer » attend deux personnes.
        app.elementAcces("delegations.nouvelle").tap()
        XCTAssertTrue(app.elementAcces("nouvelle-delegation.mandant").waitForExistence(timeout: 3))
        let inactif = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND isEnabled == false", "nouvelle-delegation.enregistrer"))
            .firstMatch
        XCTAssertTrue(inactif.exists, "rien à enregistrer sans les deux personnes")
        LancementCaptures.capturer("delegations-2-nouvelle")
    }

    @MainActor
    func testLeReportingLesAnnoncesHallEtLesCourriels() throws {
        let app = LancementCaptures.lancer()
        ouvrir("Espace CS", app)

        // Reporting : le Suivi des affaires, puis les entretiens périodiques.
        let reporting = app.elementAcces("onglet.reporting")
        XCTAssertTrue(reporting.waitForExistence(timeout: 5), "la barre d'onglets du cadre")
        reporting.tap()
        XCTAssertTrue(app.elementAcces("reporting.affaire.12").waitForExistence(timeout: 5), "la plus ancienne")
        XCTAssertTrue(app.elementAcces("reporting.total").exists)
        LancementCaptures.capturer("cs-reporting-1-suivi")
        app.elementAcces("reporting.mode.entretien").tap()
        XCTAssertTrue(app.elementAcces("reporting.affaire.40").waitForExistence(timeout: 5), "les entretiens")

        // Annonces Hall : créer une affiche, qui rejoint les archives.
        app.elementAcces("onglet.annonces-hall").tap()
        let titre = app.elementAcces("nouvelle-annonce-hall.titre")
        XCTAssertTrue(titre.waitForExistence(timeout: 5), "le formulaire")
        titre.tap()
        titre.typeText("Ascenseur à l'arrêt")
        let message = app.elementAcces("nouvelle-annonce-hall.message")
        message.tap()
        message.typeText("Intervention prévue lundi matin.")
        LancementCaptures.capturer("cs-annonces-hall-1-nouvelle")
        let creer = app.elementAcces("nouvelle-annonce-hall.creer")
        for _ in 0..<6 where !creer.isHittable { app.swipeUp() }
        creer.tap()
        XCTAssertTrue(app.elementAcces("annonce-hall.7").waitForExistence(timeout: 6), "les archives s'ouvrent")
        LancementCaptures.capturer("cs-annonces-hall-2-archives")

        // Courriels affaires : un message se déplie sur son motif et son affaire.
        let courriels = app.elementAcces("onglet.courriels")
        for _ in 0..<4 where !courriels.isHittable { app.swipeDown() }
        courriels.tap()
        let message41 = app.elementAcces("courriel.41")
        XCTAssertTrue(message41.waitForExistence(timeout: 5), "le journal")
        message41.tap()
        XCTAssertTrue(app.elementAcces("courriel.41.affaire").waitForExistence(timeout: 3), "l'affaire rejointe")
        LancementCaptures.capturer("cs-courriels-1-journal")
    }
}
