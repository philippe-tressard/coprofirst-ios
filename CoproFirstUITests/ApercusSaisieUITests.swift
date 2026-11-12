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
        let plus = app.descendants(matching: .any)["Plus"].firstMatch
        XCTAssertTrue(plus.apparait())
        plus.tap()
        let profil = app.elementAcces("plus.profil")
        _ = profil.sonde()
        for _ in 0..<6 where !(profil.exists && profil.isHittable) { app.swipeUp() }
        profil.tap()
        let modifier = app.elementAcces("profil.modifierIdentite")
        XCTAssertTrue(modifier.apparait(), "le Profil, une fois le compte lu")
        for _ in 0..<6 where !modifier.isHittable { app.swipeUp() }
        modifier.tap()
        XCTAssertTrue(
            app.elementDisant("profil.identite.nom-affiche", "Résident EXEMPLE").apparait(),
            "le nom servi avec le compte, d'emblée")
        let prenom = app.elementAcces("profil.identite.prenom")
        prenom.tap()
        prenom.typeText("e")
        XCTAssertTrue(
            app.elementDisant("profil.identite.nom-affiche", "Camille EXEMPLE").apparait(),
            "la saisie changée, le nom que le serveur en rend")
        LancementCaptures.capturer("apercus-2-profil")
    }

    func testUneFicheNeuveDeLAnnuaireSeNommeParLeServeur() throws {
        let app = LancementCaptures.lancer()
        app.ouvrirDansPlus("Espace CS")
        let annuaire = app.elementAcces("onglet.annuaire")
        XCTAssertTrue(annuaire.apparait(), "la barre d'onglets")
        annuaire.tap()
        let ajouter = app.elementAcces("cs.annuaire.conseil.ajouter")
        XCTAssertTrue(ajouter.apparait(), "le conseil")
        for _ in 0..<8 where !ajouter.isHittable { app.swipeUp() }
        ajouter.tap()
        let prenom = app.elementAcces("cs.feuille.prenom")
        XCTAssertTrue(prenom.apparait(), "la feuille d'une fiche neuve")
        prenom.tap()
        prenom.typeText("Camille")
        let nom = app.elementAcces("cs.feuille.nom")
        nom.tap()
        nom.typeText("Exemple")
        XCTAssertTrue(
            app.elementDisant("cs.feuille.nom-affiche", "Camille EXEMPLE").apparait(),
            "le nom affiché, rendu par le serveur")
        LancementCaptures.capturer("apercus-3-annuaire")
    }
}
