// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Corriger et effacer une Suite depuis l'Historique d'une affaire (#91, #93), contre
/// l'API simulée : les gestes d'une entrée sont ceux que le serveur sert avec elle.
/// Un geste se prouve par l'état qui reste — l'Historique relu —, jamais par l'avis.
final class HistoriqueUITests: XCTestCase {
    @MainActor
    private func ouvrirLAffaire(_ arguments: [String] = []) -> XCUIApplication {
        let app = LancementCaptures.lancer(arguments: arguments)
        let carte = app.buttons["fil.ticket_ouvert:41"]
        XCTAssertTrue(carte.apparait())
        carte.tap()
        XCTAssertTrue(app.attendreDetailAffaire("A-0041"))
        return app
    }

    /// L'entrée de l'Historique dont le libellé contient ce texte (elle se lit d'un trait).
    @MainActor
    private func entree(_ texte: String, dans app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", texte)).firstMatch
    }

    /// Le bouton « ⋯ » de l'entrée, amené entre les barres avant d'être touché.
    @MainActor
    private func ouvrirLesGestes(_ id: Int, dans app: XCUIApplication) {
        let gestes = app.elementAcces("historique.gestes.\(id)")
        for _ in 0..<6 where !(gestes.exists && gestes.isHittable) { app.swipeUp() }
        XCTAssertTrue(gestes.exists, "l'entrée \(id) offre ses gestes")
        gestes.tap()
    }

    /// « Enregistrer » est-il éteint ? L'identifiant peut être porté par un conteneur
    /// toujours actif : l'état se lit sur tous ses éléments (`swiftui-patterns`).
    @MainActor
    private func enregistrerEteint(_ app: XCUIApplication) -> Bool {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND isEnabled == false", "suite.enregistrer"))
            .firstMatch.exists
    }

    /// Le conseil ajoute une suite, puis la corrige depuis son entrée : la feuille part
    /// du texte servi, n'enregistre qu'un changement, et l'Historique relu le montre. Il
    /// n'efface pas : ce geste est à l'administrateur.
    @MainActor
    func testLeConseilCorrigeSaSuiteDepuisLHistorique() throws {
        let app = ouvrirLAffaire()
        // La réponse appartient à son auteur : aucun geste sur elle.
        XCTAssertFalse(app.elementAcces("historique.gestes.3").exists)

        app.elementAcces("affaire.suite").tap()
        let texte = app.elementAcces("suite.texte")
        XCTAssertTrue(texte.apparait())
        texte.tap()
        texte.typeText("Le plombier est passé.")
        app.elementAcces("suite.enregistrer").tap()
        XCTAssertTrue(entree("Le plombier est passé.", dans: app).apparait(), "la suite rejoint l'Historique")

        ouvrirLesGestes(4, dans: app)
        let modifier = app.elementAcces("historique.geste.modifier")
        XCTAssertTrue(modifier.apparait(), "« Modifier la suite »")
        XCTAssertFalse(app.elementAcces("historique.geste.supprimer").exists, "effacer est à l'administrateur")
        LancementCaptures.capturer("historique-1-gestes-du-conseil")
        modifier.tap()

        // La feuille de la Suite, partie de l'entrée : son texte servi, et rien à enregistrer.
        let servi = app.descendants(matching: .any)
            .matching(
                NSPredicate(format: "identifier == %@ AND value CONTAINS %@", "suite.texte", "Le plombier est passé.")
            ).firstMatch
        XCTAssertTrue(servi.apparait(), "le texte servi")
        XCTAssertTrue(enregistrerEteint(app), "rien n'a changé : rien à enregistrer")
        let corrige = app.elementAcces("suite.texte")
        corrige.tap()
        corrige.typeText(" Jeudi")
        LancementCaptures.capturer("historique-2-modifier-la-suite")
        app.elementAcces("suite.enregistrer").tap()

        // Le toucher pose le curseur où il tombe : on cherche le mot, pas sa place.
        XCTAssertTrue(entree("Jeudi", dans: app).apparait(), "l'entrée corrigée, relue")
        XCTAssertTrue(app.libelleAcces("Entrée corrigée").apparait(), "l'avis du geste")
    }

    /// L'administrateur efface une entrée après confirmation ; l'état de l'affaire ne
    /// change pas. Un texte mis en forme sur le site se montre sans se modifier.
    @MainActor
    func testLAdministrateurEffaceUneEntreeApresConfirmation() throws {
        let app = ouvrirLAffaire(["-compte", "administrateur"])
        // « Le syndic est prévenu » : le commentaire du conseil, que ne dit aucun message du fil.
        XCTAssertTrue(entree("Le syndic est prévenu", dans: app).exists)

        // Le commentaire porte du gras : la feuille le montre, « Enregistrer » reste éteint.
        ouvrirLesGestes(2, dans: app)
        let modifier = app.elementAcces("historique.geste.modifier")
        XCTAssertTrue(modifier.apparait())
        XCTAssertTrue(app.elementAcces("historique.geste.supprimer").exists, "l'administrateur efface")
        LancementCaptures.capturer("historique-3-gestes-de-l-administrateur")
        modifier.tap()
        XCTAssertTrue(app.elementAcces("suite.texteFige").apparait(), "un texte mis en forme ne se réécrit pas")
        XCTAssertFalse(app.elementAcces("suite.texte").exists)
        XCTAssertTrue(enregistrerEteint(app))
        app.descendants(matching: .any)["Annuler"].firstMatch.tap()
        XCTAssertTrue(app.elementAcces("suite.texteFige").disparait(), "la feuille se referme")

        ouvrirLesGestes(2, dans: app)
        let supprimer = app.elementAcces("historique.geste.supprimer")
        XCTAssertTrue(supprimer.apparait())
        supprimer.tap()
        let confirmer = app.elementAcces("historique.confirmerSuppression")
        XCTAssertTrue(confirmer.apparait(), "effacer se confirme")
        LancementCaptures.capturer("historique-4-confirmer-la-suppression")
        confirmer.tap()

        XCTAssertTrue(entree("Le syndic est prévenu", dans: app).disparait(), "l'entrée a quitté l'Historique")
        XCTAssertTrue(entree("Ouvert → Chez le syndic", dans: app).exists, "les autres entrées restent")
        XCTAssertTrue(app.libelleAcces("Entrée supprimée").apparait(), "l'avis du geste")
    }

    /// Choisit un état dans le Suivi de la feuille ouverte (le menu du sélecteur).
    @MainActor
    private func choisirLEtat(_ etat: String, dans app: XCUIApplication) {
        let suivi = app.elementAcces("suite.etat")
        XCTAssertTrue(suivi.apparait(), "le Suivi de la feuille")
        suivi.tap()
        let choix = app.descendants(matching: .any)[etat].firstMatch
        XCTAssertTrue(choix.apparait(), "« \(etat) » parmi les états")
        choix.tap()
    }

    /// Une Suite plus récente a changé l'état : corriger la première ne l'écrase pas (#187).
    /// L'alerte dit la phrase du serveur et propose l'état ; l'appliquer ajoute une Suite.
    @MainActor
    func testUneCorrectionQueLAffaireNAPasSuivieSeDitEtProposeLEtat() throws {
        let app = ouvrirLAffaire()
        app.elementAcces("affaire.suite").tap()
        choisirLEtat("Résolu", dans: app)
        app.elementAcces("suite.enregistrer").tap()
        XCTAssertTrue(entree("Chez le syndic → Résolu", dans: app).apparait(), "la Suite plus récente")

        ouvrirLesGestes(1, dans: app)
        let modifier = app.elementAcces("historique.geste.modifier")
        XCTAssertTrue(modifier.apparait())
        modifier.tap()
        choisirLEtat("Chez le prestataire", dans: app)
        app.elementAcces("suite.enregistrer").tap()

        // La phrase du serveur, telle que servie, dans l'alerte « Entrée corrigée ».
        XCTAssertTrue(app.libelleAcces("L'affaire est restée « Résolu »").apparait(), "la phrase servie")
        let appliquer = app.descendants(matching: .any)["Appliquer « Chez le prestataire » à l’affaire"].firstMatch
        XCTAssertTrue(appliquer.apparait(), "l'état proposé")
        XCTAssertTrue(app.descendants(matching: .any)["Laisser ainsi"].firstMatch.exists)
        LancementCaptures.capturer("historique-5-affaire-non-suivie")
        appliquer.tap()

        XCTAssertTrue(
            entree("Résolu → Chez le prestataire", dans: app).apparait(), "l'état appliqué par une Suite, relue")
        XCTAssertTrue(entree("Ouvert → Chez le prestataire", dans: app).exists, "l'entrée corrigée")
    }

    /// Un résident lit l'Historique sans geste : le serveur ne lui en sert aucun.
    @MainActor
    func testUnResidentLitLHistoriqueSansGeste() throws {
        let app = ouvrirLAffaire(["-compte", "resident"])
        XCTAssertTrue(entree("Ouvert → Chez le syndic", dans: app).exists)
        for id in 1...3 {
            XCTAssertFalse(app.elementAcces("historique.gestes.\(id)").exists, "aucun geste servi sur l'entrée \(id)")
        }
    }
}
