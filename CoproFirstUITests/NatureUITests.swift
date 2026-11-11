// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// La pastille de nature des cartes du fil (#78), contre l'API simulée : une affaire datée
/// dit « Calendrier » ; ce que la rubrique dit déjà (« Affaire », « Actualité ») et les
/// rubriques sans nature (document, sondage…) n'en ajoutent pas une. Une carte se lit d'un
/// bloc (VoiceOver) : son libellé porte la nature, juste après la rubrique.
final class NatureUITests: XCTestCase {
    @MainActor
    func testLaNatureSeLitSurLesAffairesDateesEtNulleParAilleurs() throws {
        let app = LancementCaptures.lancer()
        let sansDate = app.elementAcces("fil.ticket_ouvert:41")
        XCTAssertTrue(sansDate.apparait(), "le fil est chargé")
        XCTAssertFalse(sansDate.label.contains("Calendrier"), sansDate.label)
        LancementCaptures.capturer("fil-nature-1-debut")

        let actualite = app.elementAcces("fil.publication:12")
        defiler(app, jusqua: actualite)
        XCTAssertTrue(
            actualite.label.hasPrefix("Actualité, Coupure d'eau"), "la rubrique, pas deux fois : \(actualite.label)")

        let datee = app.elementAcces("fil.ticket_mis_a_jour:44")
        defiler(app, jusqua: datee)
        XCTAssertTrue(
            datee.label.hasPrefix("Affaire mise à jour, Ramonage des conduits de cheminée, Calendrier, "), datee.label)

        let document = app.elementAcces("fil.document:7")
        defiler(app, jusqua: document)
        XCTAssertFalse(document.label.contains("Calendrier"), document.label)
        LancementCaptures.capturer("fil-nature-2-calendrier-document")

        let resolue = app.elementAcces("fil.ticket_resolu:31")
        defiler(app, jusqua: resolue)
        XCTAssertTrue(resolue.label.contains(", Calendrier, "), resolue.label)
        LancementCaptures.capturer("fil-nature-3-resolue")
    }

    /// En très grand texte, la ligne passe en colonne : rubrique, heure, nature — rien ne se coupe.
    @MainActor
    func testEnAX5LaPastilleSeLitEnEntier() throws {
        let app = LancementCaptures.lancer(taille: .ax5)
        XCTAssertTrue(app.elementAcces("fil.ticket_ouvert:41").apparait(), "le fil est chargé")
        let datee = app.elementAcces("fil.ticket_mis_a_jour:44")
        // Une carte de très grand texte dépasse l'écran en hauteur : on la veut présente, pas « touchable ».
        for _ in 0..<16 where !datee.exists || datee.frame.minY > app.frame.height { app.swipeUp() }
        XCTAssertTrue(datee.label.contains("Calendrier"), datee.label)
        let carte = datee.frame
        XCTAssertLessThanOrEqual(carte.maxX, app.frame.width, "la carte ne déborde pas de l'écran : \(carte)")
        LancementCaptures.capturer("fil-nature-4-ax5")
    }

    @MainActor
    private func defiler(_ app: XCUIApplication, jusqua carte: XCUIElement) {
        for _ in 0..<16 where !carte.exists || !carte.isHittable { app.swipeUp() }
        XCTAssertTrue(carte.isHittable, "la carte est à l'écran")
    }
}
