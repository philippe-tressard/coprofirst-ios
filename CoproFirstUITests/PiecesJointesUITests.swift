// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Les pièces jointes se voient et s'ouvrent : la vignette d'une carte du fil, la mosaïque
/// et les documents d'une affaire, ceux d'une suite et d'un message — contre l'API simulée.
final class PiecesJointesUITests: XCTestCase {
    @MainActor
    private func lancer() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil", "-compte", "resident"]
        app.launch()
        return app
    }

    /// Une capture gardée au résultat, quand on la demande (`TEST_RUNNER_CAPTURES=1`) : la
    /// relecture du rendu au poste, sans peser sur la CI.
    @MainActor
    private func capturer(_ nom: String) {
        guard ProcessInfo.processInfo.environment["CAPTURES"] != nil else { return }
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = nom
        capture.lifetime = .keepAlways
        add(capture)
    }

    @MainActor
    func testLesPiecesDUneAffaireSeVoientEtSOuvrent() throws {
        let app = lancer()
        let carte = app.buttons["fil.ticket_ouvert:41"]
        XCTAssertTrue(carte.apparait())
        // La carte FERMÉE dit ses pièces (la vignette, décorative, est dans son libellé).
        XCTAssertTrue(carte.label.contains("4 photos, 1 pièce jointe"), carte.label)
        capturer("1-fil")
        carte.tap()
        XCTAssertTrue(app.attendreDetailAffaire("A-0041"))

        // La mosaïque : trois tuiles, la dernière dit les photos qui restent.
        XCTAssertTrue(app.elementAcces("pieces.photo.0").exists)
        let derniere = app.elementAcces("pieces.photo.2")
        XCTAssertTrue(derniere.exists)
        XCTAssertTrue(derniere.label.contains("et 1 de plus"), derniere.label)
        XCTAssertFalse(app.elementAcces("pieces.photo.3").exists, "une quatrième tuile ferait sauter le cadre")
        // La grande tuile fait deux fois la petite, et la colonne de droite tient dans l'écran :
        // une photo qui remplit sa case lui imposait sa largeur (vu à l'écran le 12/11/2026).
        let grande = app.elementAcces("pieces.photo.0").frame
        XCTAssertLessThanOrEqual(derniere.frame.maxX, app.frame.maxX, "la colonne de droite sort de l'écran")
        XCTAssertEqual(grande.width, 2 * derniere.frame.width, accuracy: 8, "la grande tuile fait les deux tiers")
        // Les documents, jetés avant ce lot : le type d'abord, le nom lisible ensuite.
        let devis = app.elementAcces("pieces.document.0")
        XCTAssertTrue(devis.exists)
        XCTAssertEqual(devis.label, "PDF, Devis plombier")
        capturer("2-affaire")

        // Une photo s'ouvre dans Coup d'œil, qui feuillette toutes celles de l'affaire. Le
        // toucher vise le centre : la photo doit être au-dessus du bandeau du bas, sinon il
        // tombe sur la barre (vu quand « Qui la lit », #158, l'a fait descendre).
        let photo = app.elementAcces("pieces.photo.0")
        let bandeau = app.elementAcces("affaire.lien")
        for _ in 0..<4 where photo.frame.maxY > bandeau.frame.minY - 8 { app.swipeUp() }
        XCTAssertLessThan(photo.frame.maxY, bandeau.frame.minY, "la photo est au-dessus du bandeau")
        photo.tap()
        let apercu = app.otherElements["QLPreviewControllerView"].firstMatch
        XCTAssertTrue(apercu.apparait(), "Coup d'œil s'ouvre sur la photo touchée")
        // Ouvert ne suffit pas : la photo doit s'y AFFICHER (un aperçu noir resterait vert sinon).
        XCTAssertTrue(apercu.images.firstMatch.apparait(), "la photo s'affiche")
        capturer("3-coup-d-oeil")
    }
}
