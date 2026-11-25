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
    func testLesDelegationsSAcceptentSeRevoquentEtSeCreent() throws {
        let app = LancementCaptures.lancer()
        app.ouvrirDansPlus("Délégations", jusqua: app.elementAcces("delegation.12.accepter"))

        let accepter = app.elementAcces("delegation.12.accepter")
        XCTAssertTrue(accepter.apparait(), "l'aidant accepte la délégation en attente")
        XCTAssertFalse(app.elementAcces("delegation.8.accepter").exists, "pas celle d'un autre aidant")
        LancementCaptures.capturer("delegations-1-liste")
        app.toucher(accepter)
        XCTAssertTrue(accepter.disparait(), "acceptée, elle n'attend plus")

        // Révoquer demande une confirmation.
        app.toucher(app.elementAcces("delegation.8.revoquer"))
        let confirmer = app.elementAcces("delegations.revoquer.confirmer")
        XCTAssertTrue(confirmer.apparait(), "la confirmation")
        app.toucher(confirmer)
        XCTAssertTrue(app.elementAcces("delegation.8.revoquer").disparait(), "révoquée")

        // Nouvelle délégation (conseil) : « Enregistrer » attend deux personnes.
        app.toucher(app.elementAcces("delegations.nouvelle"))
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
        app.ouvrirDansPlus("Espace CS", jusqua: app.elementAcces("onglet.reporting"))

        // Reporting : le Suivi des affaires, puis les entretiens périodiques.
        let ongletReporting = app.elementAcces("onglet.reporting")
        XCTAssertTrue(ongletReporting.apparait(), "la barre d'onglets du cadre")
        app.toucherLOnglet(ongletReporting, jusqua: app.elementAcces("reporting.affaire.12"))
        XCTAssertTrue(app.elementAcces("reporting.affaire.12").apparait(), "la plus ancienne")
        XCTAssertTrue(app.elementAcces("reporting.total").exists)
        LancementCaptures.capturer("cs-reporting-1-suivi")
        app.toucher(app.elementAcces("reporting.mode.entretien"), jusqua: app.elementAcces("reporting.affaire.40"))
        XCTAssertTrue(app.elementAcces("reporting.affaire.40").apparait(), "les entretiens")
        // Renouvellements (#56) : le relevé servi, ses compteurs et ses échéances.
        // Troisième pastille de la rangée : sur un écran de 402 pt, elle déborde à droite et
        // n'est touchable qu'en partie — sous iOS 26.5, le toucher s'y perdait (CI, #64).
        // La rangée défile d'abord jusqu'à elle : la pastille est alors entière (#183).
        let renouvellements = app.elementAcces("reporting.mode.renouvellements")
        XCTAssertTrue(app.amenerDansSaRangee(renouvellements), "la pastille entière")
        app.toucher(renouvellements)
        XCTAssertTrue(
            app.elementAcces("renouvellements.preavis").apparait(),
            "les compteurs — arbre à l'échec :\n\(app.debugDescription)")
        XCTAssertTrue(app.elementAcces("renouvellements.contrat.11").exists, "le contrat en préavis")
        LancementCaptures.capturer("cs-reporting-2-renouvellements")

        creerUneAnnonceDuHall(app)

        // Courriels affaires : un message se déplie sur son motif et son affaire.
        let message41 = app.elementAcces("courriel.41")
        app.toucherLOnglet(app.elementAcces("onglet.courriels"), jusqua: message41)
        XCTAssertTrue(message41.apparait(), "le journal")
        app.toucher(message41)
        XCTAssertTrue(app.elementAcces("courriel.41.affaire").apparait(), "l'affaire rejointe")
        LancementCaptures.capturer("cs-courriels-1-journal")
    }

    /// Annonces Hall : créer une affiche, qui rejoint les archives.
    @MainActor
    private func creerUneAnnonceDuHall(_ app: XCUIApplication) {
        let titre = app.elementAcces("nouvelle-annonce-hall.titre")
        app.toucherLOnglet(app.elementAcces("onglet.annonces-hall"), jusqua: titre)
        XCTAssertTrue(titre.apparait(), "le formulaire")
        app.toucher(titre)
        // Le retour valide le titre et ferme le clavier, qui couvrait le message : la barre de
        // navigation de l'Espace CS, touchée par `toucher` pour le fermer, ne le ferme pas (#340).
        titre.typeText("Ascenseur à l'arrêt\n")
        let message = app.elementAcces("nouvelle-annonce-hall.message")
        app.toucher(message)
        message.typeText("Intervention prévue lundi matin.")
        // Sur plusieurs lignes, le message garde le clavier au retour ; le titre le ferme : le
        // périmètre, plus bas, n'est plus sous le clavier (#340, #379).
        app.toucher(titre)
        titre.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.disparait(), "le clavier fermé avant le périmètre")
        // Le périmètre : une tête, puis l'un de ses espaces — « Bâtiment A › Toit ».
        let batiment = app.elementAcces("nouvelle-annonce-hall.perimetre.bat_a")
        for _ in 0..<4 where !batiment.isHittable { app.swipeUp() }
        app.toucher(batiment)
        let toit = app.elementAcces("nouvelle-annonce-hall.perimetre.bat_a/toit")
        XCTAssertTrue(toit.apparait(), "les espaces du bâtiment A")
        app.toucher(toit)
        XCTAssertEqual(batiment.label, "Bâtiment A › Toit", "la tête porte l'espace retenu")
        XCTAssertTrue(
            app.elementDisant("nouvelle-annonce-hall.perimetre.lieu", "Bâtiment A › Toit").apparait(),
            "le lieu retenu, nommé par le serveur (#130)")
        LancementCaptures.capturer("cs-annonces-hall-1-nouvelle")
        let creer = app.elementAcces("nouvelle-annonce-hall.creer")
        for _ in 0..<6 where !creer.isHittable { app.swipeUp() }
        app.toucher(creer)
        XCTAssertTrue(app.elementAcces("annonce-hall.7").apparait(), "les archives s'ouvrent")
        LancementCaptures.capturer("cs-annonces-hall-2-archives")
    }
}
