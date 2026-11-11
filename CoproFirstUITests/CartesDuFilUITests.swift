// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Chaque carte du fil s'ouvre, contre l'API simulée.
final class CartesDuFilUITests: XCTestCase {
    private func lancer(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil"] + arguments
        app.launch()
        return app
    }

    /// « Répondre » est le geste d'un résident : le conseil suit l'affaire par la Suite.
    @MainActor
    func testUneAffaireSOuvreEtSeRepond() throws {
        let app = lancer(["-compte", "resident"])
        let carte = app.buttons["fil.ticket_ouvert:41"]
        XCTAssertTrue(carte.waitForExistence(timeout: 5))
        carte.tap()
        XCTAssertTrue(app.attendreDetailAffaire("A-0041"))
        // La carte de l'Historique se lit d'un bloc (VoiceOver) : on cherche dans son libellé.
        let changement = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Ouvert → Chez le syndic")).firstMatch
        XCTAssertTrue(changement.exists)

        // Le bandeau d'un résident : le lien et la réponse, rien de ce que fait le conseil.
        XCTAssertTrue(app.elementAcces("affaire.lien").exists)
        XCTAssertFalse(app.elementAcces("affaire.suite").exists)
        XCTAssertFalse(app.elementAcces("affaire.archiver").exists)
        // Le fil des messages, sous l'Historique : la note interne du conseil n'y est pas.
        XCTAssertTrue(app.elementAcces("affaire.message.502").exists)
        XCTAssertFalse(app.elementAcces("affaire.message.503").exists, "une note interne est au conseil seul")
        app.elementAcces("affaire.repondre").tap()
        let texte = app.elementAcces("repondre.texte")
        XCTAssertTrue(texte.waitForExistence(timeout: 3))
        texte.typeText("Merci, je contourne la zone.")
        app.elementAcces("repondre.envoyer").tap()
        XCTAssertTrue(app.elementAcces("affaire.repondre").waitForExistence(timeout: 5), "la feuille se referme")
        // La réponse est un MESSAGE (comme sur le site), pas une suite de l'Historique.
        let message = app.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "affaire.message.",
                    "Merci, je contourne la zone.")
            ).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5), "la réponse rejoint le fil des messages")
    }

    /// Le conseil syndical : 🔗 · 🔄 · options · 📦, sans « Répondre » ; une Suite qui
    /// change l'état rejoint l'Historique, l'archivage retire 📦.
    @MainActor
    func testLeConseilSuitEtArchiveDepuisLeBandeau() throws {
        let app = lancer()
        let carte = app.buttons["fil.ticket_ouvert:41"]
        XCTAssertTrue(carte.waitForExistence(timeout: 5))
        carte.tap()
        XCTAssertTrue(app.attendreDetailAffaire("A-0041"))
        let suite = app.elementAcces("affaire.suite")
        XCTAssertTrue(suite.exists)
        XCTAssertTrue(app.elementAcces("affaire.options").exists)
        XCTAssertFalse(app.elementAcces("affaire.repondre").exists, "le conseil ne répond pas, il suit")
        XCTAssertTrue(app.elementAcces("affaire.message.503").exists, "la note interne, au conseil")

        suite.tap()
        let texte = app.elementAcces("suite.texte")
        XCTAssertTrue(texte.waitForExistence(timeout: 3))
        texte.tap()
        texte.typeText("Le plombier est passé.")
        app.elementAcces("suite.enregistrer").tap()
        let ajoutee = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Le plombier est passé.")).firstMatch
        XCTAssertTrue(ajoutee.waitForExistence(timeout: 5), "la suite rejoint l'Historique")

        app.elementAcces("affaire.archiver").tap()
        let archivee = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Affaire archivée")).firstMatch
        XCTAssertTrue(archivee.waitForExistence(timeout: 5))
        XCTAssertFalse(app.elementAcces("affaire.archiver").exists)
    }

    /// ✏️ (#91) : la feuille part de l'affaire servie, n'enregistre qu'un changement, et
    /// l'affaire relue le montre.
    @MainActor
    func testLeConseilModifieLAffaireDepuisLeBandeau() throws {
        let app = lancer()
        let carte = app.buttons["fil.ticket_ouvert:41"]
        XCTAssertTrue(carte.waitForExistence(timeout: 5))
        carte.tap()
        XCTAssertTrue(app.attendreDetailAffaire("A-0041"))
        let modifier = app.elementAcces("affaire.modifier")
        XCTAssertTrue(modifier.exists)
        modifier.tap()

        let titre = app.textFields["modifier.titre"]
        XCTAssertTrue(titre.waitForExistence(timeout: 3))
        let enregistrer = app.buttons["modifier.enregistrer"]
        XCTAssertFalse(enregistrer.isEnabled, "rien n'a changé : rien à enregistrer")
        XCTAssertTrue(app.elementAcces("nouvelle.categorie.sinistre").exists, "le conseil peut changer la catégorie")
        titre.tap()
        titre.typeText(" nord")
        enregistrer.tap()

        let modifiee = app.descendants(matching: .any)
            // Le toucher pose le curseur où il tombe : on cherche le mot, pas sa place.
            .matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Fuite d'eau", "nord"))
            .firstMatch
        XCTAssertTrue(modifiee.waitForExistence(timeout: 5), "le nouveau titre, relu")
    }

    /// #98 : un détail servi en 8 s — bien plus que les 5 s qu'attendaient ces tests — se lit
    /// quand même, bandeau compris : on attend le détail chargé, jamais une durée.
    @MainActor
    func testUnDetailLentSAttendJusquASonBandeau() throws {
        let app = lancer(["-delai-detail", "8000"])
        let carte = app.buttons["fil.ticket_ouvert:41"]
        XCTAssertTrue(carte.waitForExistence(timeout: 5))
        carte.tap()
        XCTAssertTrue(app.attendreDetailAffaire("A-0041"))
        XCTAssertTrue(app.elementAcces("affaire.suite").exists)
        XCTAssertTrue(app.elementAcces("affaire.message.503").exists)
    }

    @MainActor
    func testUnSondageUnDocumentEtUnResumeSOuvrent() throws {
        let app = lancer()
        let sondage = app.buttons["fil.sondage_ouvert:3"]
        XCTAssertTrue(sondage.waitForExistence(timeout: 5))
        sondage.tap()
        XCTAssertTrue(app.elementAcces("sondage.option.1").waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        let document = app.buttons["fil.document:7"]
        XCTAssertTrue(document.waitForExistence(timeout: 5))
        document.tap()
        XCTAssertTrue(app.navigationBars["Procès-verbal de l'assemblée générale"].waitForExistence(timeout: 8))
        app.navigationBars.buttons.firstMatch.tap()

        let point = app.buttons["fil.point_conseil:2"]
        if !point.isHittable { app.swipeUp() }
        XCTAssertTrue(point.waitForExistence(timeout: 5))
        point.tap()
        XCTAssertTrue(
            app.staticTexts["Ordre du jour : ascenseur, ravalement, contrat d'entretien."].waitForExistence(timeout: 5))
    }
}
