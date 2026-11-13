// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Plusieurs prestataires par affaire (#181, coprofirst#2704), contre l'API simulée : la
/// fiche les dit un par ligne, ✏️ en ajoute et en retire selon le droit servi, et la carte
/// du Kanban montre le premier puis « +N ».
final class PrestatairesAffaireUITests: XCTestCase {
    private func lancer(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee"] + arguments
        app.launch()
        return app
    }

    /// A-0045 est servie à la forme du contrat 1.28.0 avec deux prestataires ; le conseil
    /// retire le second, ajoute un troisième, et la fiche relue le montre.
    @MainActor
    func testLeConseilRetireEtAjouteUnPrestataire() throws {
        let app = lancer(["-ecran", "fil"])
        let carte = app.elementAcces("fil.ticket_mis_a_jour:45")
        XCTAssertTrue(carte.apparait())
        app.amener(carte)
        carte.tap()
        XCTAssertTrue(app.attendreDetailAffaire("A-0045"))
        XCTAssertTrue(
            app.elementDisant(
                "affaire.intervenant", "Intervenants : Ascenseurs du Parc (fictif), Contrôles Sécurité Exemple"
            ).exists, "une ligne par prestataire, lue d'un bloc")

        app.elementAcces("affaire.modifier").tap()
        let enregistrer = app.buttons["modifier.enregistrer"]
        XCTAssertTrue(enregistrer.apparait())
        let retirer = app.elementAcces("modifier.prestataire.2.retirer")
        XCTAssertTrue(app.amener(retirer), "chaque prestataire a son ×")
        retirer.tap()
        XCTAssertTrue(app.elementAcces("modifier.prestataire.2").disparait())
        XCTAssertTrue(enregistrer.isEnabled, "la liste a changé : elle part")

        let ajouter = app.elementAcces("modifier.prestataires.ajouter")
        XCTAssertTrue(app.amener(ajouter))
        ajouter.tap()
        // Le menu du système ne fait pas toujours descendre les identifiants : son libellé.
        let choix = app.descendants(matching: .any)["Eaux de la Ville (fictif)"].firstMatch
        XCTAssertTrue(choix.apparait(), "« Ajouter » propose ceux qui n'y sont pas")
        choix.tap()
        XCTAssertTrue(app.elementAcces("modifier.prestataire.3").apparait())
        app.capturerAcces("prestataires-modifier", dans: self)
        enregistrer.tap()

        XCTAssertTrue(
            app.elementDisant(
                "affaire.intervenant", "Intervenants : Ascenseurs du Parc (fictif), Eaux de la Ville (fictif)"
            ).apparait(), "la fiche relue dit la nouvelle liste")
        app.capturerAcces("prestataires-fiche", dans: self)
    }

    /// Un résident garde le crayon de son affaire (A-0041), sans le droit servi sur les
    /// prestataires : la section n'est pas offerte.
    @MainActor
    func testSansLeDroitServiPasDeSectionPrestataires() throws {
        let app = lancer(["-ecran", "fil", "-compte", "resident"])
        let carte = app.buttons["fil.ticket_ouvert:41"]
        XCTAssertTrue(carte.apparait())
        carte.tap()
        XCTAssertTrue(app.attendreDetailAffaire("A-0041"))
        app.elementAcces("affaire.modifier").tap()
        XCTAssertTrue(app.buttons["modifier.enregistrer"].apparait())
        XCTAssertFalse(app.amener(app.elementAcces("modifier.prestataires.ajouter"), essais: 4))
    }

    /// La carte du Kanban montre le premier prestataire et « +1 » ; VoiceOver lit les deux.
    @MainActor
    func testLaCarteDuKanbanDitLePremierEtPlusN() throws {
        let app = lancer(["-ecran", "affaires"])
        // L'écran s'ouvre sur la barre : le menu Affaires d'abord, comme AffairesUITests.
        let menu = app.descendants(matching: .any)["Affaires"].firstMatch
        XCTAssertTrue(menu.apparait())
        menu.tap()
        let onglet = app.descendants(matching: .any)["Kanban"].firstMatch
        XCTAssertTrue(onglet.apparait(), "l'onglet, une fois la liste chargée")
        onglet.tap()
        XCTAssertTrue(app.elementAcces("kanban.colonne.cs").apparait())
        // « Chez le prestataire » est une colonne à droite : on y va.
        let carte = app.elementAcces("kanban.carte.A-0040")
        for _ in 0..<5 where !(carte.exists && carte.isHittable) { app.swipeLeft() }
        XCTAssertTrue(carte.exists)
        XCTAssertTrue(
            app.elementDisant("kanban.carte.A-0040", "Ascenseurs du Val, Dépannages Exemple").exists,
            "la liste entière au libellé")
        app.capturerAcces("prestataires-kanban", dans: self)
    }
}
