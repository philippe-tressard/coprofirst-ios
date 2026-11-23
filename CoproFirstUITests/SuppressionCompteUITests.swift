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
        app.ouvrirLeProfil()
        return app
    }

    @MainActor
    func testLaDemandeSeFaitAvecLeMotDePasseEtSeRetire() throws {
        let app = ouvrirLeProfil()
        let demander = app.elementAcces("profil.suppression.demander")
        XCTAssertTrue(app.amener(demander, essais: 40), "le geste, sous « Vos droits »")
        LancementCaptures.capturer("suppression-1-invitation")
        // La feuille s'ouvre JUSQU'À son titre : sous charge, le toucher se perdait et la
        // feuille ne montait pas (main b247512, lot 3, #282).
        app.toucher(demander, jusqua: app.navigationBars["Supprimer mon compte"], essais: 40)

        // La feuille dit ce qui sera effacé (phrases servies) avant de demander quoi que ce soit.
        let motDePasse = app.elementAcces("suppression.motDePasse")
        // Aux grandes tailles, la feuille défile : les phrases d'abord, le champ plus bas.
        let perte = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Ancien résident"))
            .firstMatch
        XCTAssertTrue(
            app.amener(perte, essais: 40, pourLire: true),
            "ce que la personne perd et ce qui reste, dit avant de confirmer")
        LancementCaptures.capturer("suppression-2a-ce-qui-reste")
        XCTAssertTrue(app.amener(motDePasse, essais: 40), "la confirmation demande le mot de passe")
        let confirmer = app.elementAcces("suppression.confirmer")
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@ AND isEnabled == false", "suppression.confirmer"))
                .firstMatch.sonde(),
            "sans mot de passe, « Confirmer » reste fermé")
        LancementCaptures.capturer("suppression-2-confirmation")

        // Un mot de passe refusé par le serveur : la phrase du serveur, la feuille reste.
        app.toucher(motDePasse, essais: 40)
        motDePasse.typeText("refuse")
        // « Confirmer », bouton de la barre de la feuille : `toucher` attend qu'il soit
        // touchable avant tout défilement — en faire défiler la feuille la fermait (#232, #217).
        app.toucher(confirmer)
        let refus = app.staticTexts["Mot de passe incorrect."].firstMatch
        XCTAssertTrue(app.amener(refus, essais: 20, pourLire: true), "le refus du serveur, en toutes lettres")
        LancementCaptures.capturer("suppression-3-refus")

        // Le bon mot de passe : la demande part, la feuille se ferme.
        app.toucher(motDePasse, essais: 40)
        // Efface « refuse » touche par touche : le menu « Tout sélectionner » dépend de la langue.
        motDePasse.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "refuse".count))
        motDePasse.typeText("secret")
        app.toucher(confirmer)
        let retirer = app.elementAcces("profil.suppression.retirer")
        XCTAssertTrue(retirer.apparait(), "la demande est envoyée : on peut la retirer")
        XCTAssertFalse(app.elementAcces("profil.suppression.demander").exists)
        LancementCaptures.capturer("suppression-4-demande-envoyee")

        // Retirée : le compte est conservé, le geste revient.
        app.toucher(retirer)
        XCTAssertTrue(app.elementAcces("profil.suppression.demander").apparait(), "demande retirée")
    }
}
