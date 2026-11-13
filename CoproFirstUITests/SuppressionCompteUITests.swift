// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// « Supprimer mon compte » (#166) : ce que la revue d'Apple joue (règle 5.1.1 v) — la
/// demande depuis le Profil, le mot de passe exigé, la demande retirable. Sur l'API
/// simulée : « refuse » comme mot de passe est refusé, comme le fait le serveur.
final class SuppressionCompteUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func ouvrirLeProfil() -> XCUIApplication {
        let app = LancementCaptures.lancer()
        let plus = app.descendants(matching: .any)["Plus"].firstMatch
        XCTAssertTrue(plus.apparait())
        plus.tap()
        let profil = app.elementAcces("plus.profil")
        XCTAssertTrue(app.amener(profil), "« Profil » dans la liste « Plus »")
        profil.tap()
        return app
    }

    @MainActor
    func testLaDemandeSeFaitAvecLeMotDePasseEtSeRetire() throws {
        let app = ouvrirLeProfil()
        let demander = app.elementAcces("profil.suppression.demander")
        XCTAssertTrue(app.amener(demander), "le geste, sous « Vos droits »")
        LancementCaptures.capturer("suppression-1-invitation")
        demander.tap()

        // La feuille dit ce qui sera effacé (phrases servies) avant de demander quoi que ce soit.
        let motDePasse = app.elementAcces("suppression.motDePasse")
        XCTAssertTrue(motDePasse.apparait(), "la confirmation demande le mot de passe")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Ancien résident"))
            .firstMatch.sonde(), "ce que la personne perd et ce qui reste, dit avant de confirmer")
        let confirmer = app.elementAcces("suppression.confirmer")
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@ AND isEnabled == false", "suppression.confirmer"))
                .firstMatch.sonde(),
            "sans mot de passe, « Confirmer » reste fermé")
        LancementCaptures.capturer("suppression-2-confirmation")

        // Un mot de passe refusé par le serveur : la phrase du serveur, la feuille reste.
        motDePasse.tap()
        motDePasse.typeText("refuse")
        confirmer.tap()
        XCTAssertTrue(
            app.staticTexts["Mot de passe incorrect."].apparait(), "le refus du serveur, en toutes lettres")
        LancementCaptures.capturer("suppression-3-refus")

        // Le bon mot de passe : la demande part, la feuille se ferme.
        motDePasse.tap()
        // Efface « refuse » touche par touche : le menu « Tout sélectionner » dépend de la langue.
        motDePasse.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "refuse".count))
        motDePasse.typeText("secret")
        confirmer.tap()
        let retirer = app.elementAcces("profil.suppression.retirer")
        XCTAssertTrue(retirer.apparait(), "la demande est envoyée : on peut la retirer")
        XCTAssertFalse(app.elementAcces("profil.suppression.demander").exists)
        LancementCaptures.capturer("suppression-4-demande-envoyee")

        // Retirée : le compte est conservé, le geste revient.
        retirer.tap()
        XCTAssertTrue(app.elementAcces("profil.suppression.demander").apparait(), "demande retirée")
    }
}
