// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// « Prénom NOM » d'une saisie, rendu par le serveur (#135), contre l'API simulée — qui
/// sert une réponse fixe (`FixturesApercus`) : le Profil l'ouvre sur le nom servi avec le
/// compte, sans le redemander ; une fiche neuve de l'annuaire du conseil le dit dès la
/// frappe. « Qui la lira » et le lieu : `SaisieAffaireUITests`, `DelegationsCSUITests`.
/// Recherche par identifiant, jamais par type (`AccesUITests`).
@MainActor
final class ApercusSaisieUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testLeProfilSOuvreSurLeNomServiPuisSuitLaFrappe() throws {
        let app = LancementCaptures.lancer()
        app.ouvrirLeProfil()
        let modifier = app.elementAcces("profil.modifierIdentite")
        XCTAssertTrue(modifier.apparait(), "le Profil, une fois le compte lu")
        for _ in 0..<6 where !modifier.isHittable { app.swipeUp() }
        app.toucher(modifier)
        XCTAssertTrue(
            app.elementDisant("profil.identite.nom-affiche", "Résident EXEMPLE").apparait(),
            "le nom servi avec le compte, d'emblée")
        // #411 : le titre dans le contenu, entier — la barre le tronquait en « Informations… ».
        let titre = app.elementAcces("profil.identite.titre")
        XCTAssertEqual(titre.label, "Informations personnelles", "le titre de la feuille, entier")
        XCTAssertFalse(app.navigationBars.staticTexts["Informations personnelles"].exists, "aucun titre dans la barre")
        let prenom = app.elementAcces("profil.identite.prenom")
        app.toucher(prenom)
        prenom.typeText("e")
        XCTAssertTrue(
            app.elementDisant("profil.identite.nom-affiche", "Camille EXEMPLE").apparait(),
            "la saisie changée, le nom que le serveur en rend")
        LancementCaptures.capturer("apercus-2-profil")
    }

    func testUneFicheNeuveDeLAnnuaireSeNommeParLeServeur() throws {
        let app = LancementCaptures.lancer()
        app.ouvrirDansPlus("Espace CS", jusqua: app.elementAcces("onglet.annuaire"))
        let ongletAnnuaire = app.elementAcces("onglet.annuaire")
        XCTAssertTrue(ongletAnnuaire.apparait(), "la barre d'onglets")
        let ajouter = app.elementAcces("cs.annuaire.conseil.ajouter")
        app.toucherLOnglet(ongletAnnuaire, jusqua: ajouter)
        XCTAssertTrue(ajouter.apparait(), "le conseil")
        for _ in 0..<8 where !ajouter.isHittable { app.swipeUp() }
        app.toucher(ajouter)
        let prenom = app.elementAcces("cs.feuille.prenom")
        XCTAssertTrue(prenom.apparait(), "la feuille d'une fiche neuve")
        app.toucher(prenom)
        prenom.typeText("Camille")
        let nom = app.elementAcces("cs.feuille.nom")
        app.toucher(nom)
        nom.typeText("Exemple")
        XCTAssertTrue(
            app.elementDisant("cs.feuille.nom-affiche", "Camille EXEMPLE").apparait(),
            "le nom affiché, rendu par le serveur")
        LancementCaptures.capturer("apercus-3-annuaire")
    }
}
