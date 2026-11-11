// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Un lien universel reçu au lancement (`-lien`, #18), par la porte qu'empruntent aussi
/// les notifications (#17) — contre l'API simulée. Captures : `LancementCaptures`.
final class LiensUITests: XCTestCase {
    /// Le lien d'un courriel « nouvelle réponse » : l'affaire, dans l'onglet Affaires.
    @MainActor
    func testUnLienOuvreLAffaireDansSonOnglet() throws {
        let app = LancementCaptures.lancer(arguments: ["-lien", "https://tilleuls.exemple.fr/tickets/41#msg-502"])
        XCTAssertTrue(app.attendreDetailAffaire("A-0041"))
        LancementCaptures.capturer("lien-1-affaire")
        // Le retour mène à la liste des affaires : l'affaire est dans SON onglet.
        app.navigationBars["A-0041"].buttons.firstMatch.tap()
        XCTAssertTrue(app.elementAcces("affaires.carte.A-0041").waitForExistence(timeout: 5))
    }

    /// Une résidence jamais vue : la connexion, son adresse pré-remplie — rien d'autre.
    @MainActor
    func testUnHoteJamaisVuOuvreLaConnexionPreRemplie() throws {
        let app = LancementCaptures.lancer(arguments: ["-lien", "https://inconnue.exemple.org/tickets/3"])
        let prerempli = NSPredicate(
            format: "identifier == %@ AND value == %@", "connexion.residence", "inconnue.exemple.org")
        let champ = app.descendants(matching: .any).matching(prerempli).firstMatch
        XCTAssertTrue(champ.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["A-0003"].exists)
        LancementCaptures.capturer("lien-2-hote-inconnu")
    }
}
