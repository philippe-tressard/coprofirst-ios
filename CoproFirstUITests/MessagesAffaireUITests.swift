// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Modifier puis retirer SON message du fil d'une affaire (#211), contre l'API simulée :
/// le « ⋯ » de sa bulle, la feuille de « Répondre » qui part de son texte, la question du
/// site avant de retirer. Un geste se prouve par le fil relu, jamais par l'avis seul.
final class MessagesAffaireUITests: XCTestCase {
    @MainActor
    func testSonMessageSeModifiePuisSeRetire() throws {
        let app = LancementCaptures.lancer()
        let carte = app.buttons["fil.ticket_ouvert:41"]
        XCTAssertTrue(carte.apparait())
        app.toucher(carte)
        XCTAssertTrue(app.attendreDetailAffaire("A-0041"))

        // Le message d'un autre n'a pas de geste ; le sien, si.
        XCTAssertFalse(app.elementAcces("message.gestes.502").exists, "le message du conseil")
        let gestes = app.elementAcces("message.gestes.501")
        // Au-dessus du bandeau du bas (🔗 y est offert à tous) : sous son verre, le « ⋯ » ne
        // s'ouvre pas (iOS 26.5).
        let bandeau = app.elementAcces("affaire.lien")
        XCTAssertTrue(app.amener(gestes, auDessusDe: bandeau), "son message offre ses gestes")
        app.toucher(gestes)
        let modifier = app.elementAcces("message.geste.modifier")
        XCTAssertTrue(modifier.apparait(), "« Modifier mon message »")
        XCTAssertTrue(app.elementAcces("message.geste.supprimer").exists, "« Supprimer mon message »")
        LancementCaptures.capturer("messages-1-gestes")
        app.toucher(modifier)

        // La feuille part du texte servi ; on y ajoute un mot, puis on enregistre.
        let texte = app.elementAcces("repondre.texte")
        XCTAssertTrue(texte.apparait())
        XCTAssertTrue((texte.value as? String)?.contains("le seau est presque plein") == true, "le texte servi")
        app.toucher(texte)
        texte.typeText(" Vidé ce matin.")
        LancementCaptures.capturer("messages-2-modifier")
        app.toucher(app.elementAcces("repondre.envoyer"))

        let message = app.elementAcces("affaire.message.501")
        XCTAssertTrue(message.attendre("label CONTAINS 'Vidé ce matin.'"), "le fil relu montre le message corrigé")

        // Retirer : la question du site, puis le message quitte le fil.
        XCTAssertTrue(app.amener(gestes, auDessusDe: bandeau))
        app.toucher(gestes)
        let supprimer = app.elementAcces("message.geste.supprimer")
        XCTAssertTrue(supprimer.apparait())
        app.toucher(supprimer)
        let confirmer = app.elementAcces("message.confirmerSuppression")
        XCTAssertTrue(confirmer.apparait(), "retirer se confirme")
        LancementCaptures.capturer("messages-3-confirmer")
        app.toucher(confirmer)
        XCTAssertTrue(message.disparait(), "le message a quitté le fil")
        XCTAssertTrue(app.elementAcces("affaire.message.502").exists, "les autres restent")
    }
}
