// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Masquer ce que publie un résident (#286), contre l'API simulée, qui sert le contrat du
/// plancher (les masquages y sont depuis v3.121.2, #313) : le geste se pose depuis une suite
/// d'affaire, se confirme, et se défait dans le Profil. Un geste se prouve par l'état qui
/// reste, jamais par l'avis seul.
@MainActor
final class ModerationUITests: XCTestCase {
    private let porte = ["-compte", "resident"]

    override func setUp() {
        continueAfterFailure = false
    }

    /// La réponse du syndic, sur l'affaire 41 : « ⋯ » offre de la signaler et de masquer son
    /// auteur ; la confirmation dit ce qui disparaît, et l'avis le confirme.
    func testUneSuiteDUnAutreSeSignaleEtSonAuteurSeMasque() throws {
        let app = LancementCaptures.lancer(arguments: porte)
        let carte = app.elementAcces("fil.ticket_ouvert:41")
        XCTAssertTrue(carte.apparait())
        app.toucher(carte)
        XCTAssertTrue(app.attendreDetailAffaire("A-0041"))

        // Au-dessus du bandeau du bas (🔗 y est offert à tous) : passé sous lui, le « ⋯ »
        // recevait le toucher sur le bandeau (rouge en CI, iOS 26.5) — l'aide de #307.
        let gestes = app.elementAcces("historique.gestes.3")
        let bandeau = app.elementAcces("affaire.lien")
        XCTAssertTrue(app.amener(gestes, auDessusDe: bandeau), "la réponse du syndic offre ses gestes")
        app.toucher(gestes)
        XCTAssertTrue(app.elementAcces("historique.geste.signaler").apparait(), "« Signaler cette suite »")
        let masquer = app.elementAcces("historique.geste.masquer")
        XCTAssertTrue(masquer.exists, "« Masquer ce que publie Le syndic »")
        LancementCaptures.capturer("moderation-1-gestes-d-une-suite")
        app.toucher(masquer)

        XCTAssertTrue(app.elementAcces("Masquer ce que publie Le syndic ?").apparait(), "la question du site")
        app.toucher(app.elementAcces("masquage.confirmer"))
        XCTAssertTrue(app.elementAcces("Ce que publie Le syndic est masqué pour vous").apparait())
    }

    /// Profil › Personnes masquées : la liste servie, puis « Ne plus masquer » la retire.
    func testLeProfilListeLesPersonnesMasqueesEtLesDemasque() throws {
        let app = LancementCaptures.lancer(arguments: porte)
        app.ouvrirLeProfil()
        // Sous « Ce que j'affiche », plus bas que l'écran : une liste ne crée ses rangées
        // qu'en approchant, on la fait défiler jusqu'à elle.
        let entree = app.elementAcces("profil.masquees")
        for _ in 0..<8 where entree.sonde() == false { app.swipeUp() }
        XCTAssertTrue(entree.exists, "l'entrée, le compte lu")
        app.toucher(entree)

        let ligne = app.elementAcces("masque.31")
        XCTAssertTrue(ligne.apparait(), "la personne masquée, servie")
        LancementCaptures.capturer("moderation-2-personnes-masquees")
        app.toucher(app.elementAcces("masque.31.demasquer"))
        XCTAssertTrue(ligne.disparait(), "elle quitte la liste")
        XCTAssertTrue(app.elementAcces("Personne n’est masqué").apparait(), "la liste vide le dit")
    }
}
