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
        XCTAssertTrue(plus.apparait())
        plus.tap()
        let entree = app.libelleAcces(libelle)
        // Aux grandes tailles, la ligne est sous le pli : la liste ne la crée qu'au défilement.
        _ = entree.sonde()
        for _ in 0..<6 where !(entree.exists && entree.isHittable) { app.swipeUp() }
        XCTAssertTrue(entree.exists, "« \(libelle) » dans Plus")
        entree.tap()
    }

    @MainActor
    func testLesDelegationsSAcceptentSeRevoquentEtSeCreent() throws {
        let app = LancementCaptures.lancer()
        ouvrir("Délégations", app)

        let accepter = app.elementAcces("delegation.12.accepter")
        XCTAssertTrue(accepter.apparait(), "l'aidant accepte la délégation en attente")
        XCTAssertFalse(app.elementAcces("delegation.8.accepter").exists, "pas celle d'un autre aidant")
        LancementCaptures.capturer("delegations-1-liste")
        accepter.tap()
        XCTAssertTrue(accepter.disparait(), "acceptée, elle n'attend plus")

        // Révoquer demande une confirmation.
        app.elementAcces("delegation.8.revoquer").tap()
        let confirmer = app.elementAcces("delegations.revoquer.confirmer")
        XCTAssertTrue(confirmer.apparait(), "la confirmation")
        confirmer.tap()
        XCTAssertTrue(app.elementAcces("delegation.8.revoquer").disparait(), "révoquée")

        // Nouvelle délégation (conseil) : « Enregistrer » attend deux personnes.
        app.elementAcces("delegations.nouvelle").tap()
        XCTAssertTrue(app.elementAcces("nouvelle-delegation.mandant").apparait())
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
        XCTAssertTrue(reporting.apparait(), "la barre d'onglets du cadre")
        reporting.tap()
        XCTAssertTrue(app.elementAcces("reporting.affaire.12").apparait(), "la plus ancienne")
        XCTAssertTrue(app.elementAcces("reporting.total").exists)
        LancementCaptures.capturer("cs-reporting-1-suivi")
        app.elementAcces("reporting.mode.entretien").tap()
        XCTAssertTrue(app.elementAcces("reporting.affaire.40").apparait(), "les entretiens")
        // Renouvellements (#56) : le relevé servi, ses compteurs et ses échéances.
        // Troisième pastille de la rangée : sur un écran de 402 pt, elle déborde à droite et
        // n'est touchable qu'en partie — sous iOS 26.5, le toucher s'y perdait (CI, #64).
        // La rangée défile d'abord jusqu'au bout : la pastille est alors entière.
        app.elementAcces("reporting.mode.entretien").swipeLeft()
        app.elementAcces("reporting.mode.renouvellements").tap()
        XCTAssertTrue(
            app.elementAcces("renouvellements.preavis").apparait(),
            "les compteurs — arbre à l'échec :\n\(app.debugDescription)")
        XCTAssertTrue(app.elementAcces("renouvellements.contrat.11").exists, "le contrat en préavis")
        LancementCaptures.capturer("cs-reporting-2-renouvellements")

        // Annonces Hall : créer une affiche, qui rejoint les archives.
        app.elementAcces("onglet.annonces-hall").tap()
        let titre = app.elementAcces("nouvelle-annonce-hall.titre")
        XCTAssertTrue(titre.apparait(), "le formulaire")
        titre.tap()
        titre.typeText("Ascenseur à l'arrêt")
        let message = app.elementAcces("nouvelle-annonce-hall.message")
        message.tap()
        message.typeText("Intervention prévue lundi matin.")
        // Le périmètre : une tête, puis l'un de ses espaces — « Bâtiment A › Toit ».
        let batiment = app.elementAcces("nouvelle-annonce-hall.perimetre.bat_a")
        for _ in 0..<4 where !batiment.isHittable { app.swipeUp() }
        batiment.tap()
        let toit = app.elementAcces("nouvelle-annonce-hall.perimetre.bat_a/toit")
        XCTAssertTrue(toit.apparait(), "les espaces du bâtiment A")
        toit.tap()
        XCTAssertEqual(batiment.label, "Bâtiment A › Toit", "la tête porte l'espace retenu")
        LancementCaptures.capturer("cs-annonces-hall-1-nouvelle")
        let creer = app.elementAcces("nouvelle-annonce-hall.creer")
        for _ in 0..<6 where !creer.isHittable { app.swipeUp() }
        creer.tap()
        XCTAssertTrue(app.elementAcces("annonce-hall.7").apparait(), "les archives s'ouvrent")
        LancementCaptures.capturer("cs-annonces-hall-2-archives")

        // Courriels affaires : un message se déplie sur son motif et son affaire.
        let courriels = app.elementAcces("onglet.courriels")
        for _ in 0..<4 where !courriels.isHittable { app.swipeDown() }
        courriels.tap()
        let message41 = app.elementAcces("courriel.41")
        XCTAssertTrue(message41.apparait(), "le journal")
        message41.tap()
        XCTAssertTrue(app.elementAcces("courriel.41.affaire").apparait(), "l'affaire rejointe")
        LancementCaptures.capturer("cs-courriels-1-journal")
    }
}
