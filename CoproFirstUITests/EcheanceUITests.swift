// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// La vignette d'échéance des affaires datées du fil (#75), contre l'API simulée : à venir,
/// jour J, sur plusieurs jours, passée, close, et une affaire sans date qui n'en a pas.
/// Une carte se lit d'un bloc (VoiceOver) : son libellé porte le délai et les dates.
final class EcheanceUITests: XCTestCase {
    @MainActor
    func testLesAffairesDateesDisentQuandEllesOntLieu() throws {
        let app = LancementCaptures.lancer()
        // Chaque carte est amenée à l'écran avant d'être lue : en très grand texte, le fil
        // paresseux ne crée pas celles du dessous.
        let sansDate = app.elementAcces("fil.ticket_ouvert:41")
        XCTAssertTrue(sansDate.waitForExistence(timeout: 8), "le fil est chargé")
        XCTAssertFalse(sansDate.label.contains("prévu"), "une affaire sans date n'a pas de vignette")
        let aVenir = app.elementAcces("fil.publication:12")
        defiler(app, jusqua: aVenir)
        XCTAssertTrue(aVenir.label.contains("J-2, prévu le "), aVenir.label)
        let jourJ = app.elementAcces("fil.ticket_mis_a_jour:44")
        defiler(app, jusqua: jourJ)
        XCTAssertTrue(jourJ.label.contains("Jour J, prévu le "), jourJ.label)
        LancementCaptures.capturer("fil-echeance-1-jour-j-a-venir-sans-date")

        let plage = app.elementAcces("fil.ticket_mis_a_jour:38")
        defiler(app, jusqua: plage)
        XCTAssertTrue(plage.label.contains("J-8, prévu du "), plage.label)
        let passee = app.elementAcces("fil.ticket_mis_a_jour:45")
        defiler(app, jusqua: passee)
        XCTAssertTrue(passee.label.contains("Passé, prévu le "), passee.label)
        LancementCaptures.capturer("fil-echeance-2-plusieurs-jours-passee")

        let close = app.elementAcces("fil.ticket_resolu:31")
        defiler(app, jusqua: close)
        XCTAssertTrue(close.label.contains(", prévu le "), close.label)
        XCTAssertFalse(close.label.contains("J-"), "une affaire close n'a plus de délai")
        LancementCaptures.capturer("fil-echeance-3-close")

        // La carte s'ouvre comme avant : la vignette n'en change pas le geste.
        close.tap()
        XCTAssertTrue(app.attendreDetailAffaire("A-0031"))
    }

    @MainActor
    private func defiler(_ app: XCUIApplication, jusqua carte: XCUIElement) {
        for _ in 0..<16 where !carte.exists || !carte.isHittable { app.swipeUp() }
        XCTAssertTrue(carte.isHittable, "la carte est à l'écran")
    }
}
