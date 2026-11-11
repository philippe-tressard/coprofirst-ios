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
        XCTAssertTrue(carte.apparait())
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
        XCTAssertTrue(texte.apparait())
        texte.typeText("Merci, je contourne la zone.")
        app.elementAcces("repondre.envoyer").tap()
        XCTAssertTrue(app.elementAcces("affaire.repondre").apparait(), "la feuille se referme")
        // La réponse est un MESSAGE (comme sur le site), pas une suite de l'Historique.
        let message = app.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "affaire.message.",
                    "Merci, je contourne la zone.")
            ).firstMatch
        XCTAssertTrue(message.apparait(), "la réponse rejoint le fil des messages")
    }

    /// L'auteur d'une affaire engagée garde le crayon (`peut_corriger`, #127), comme sur le
    /// site : la feuille s'ouvre, son contenu se montre sans se modifier.
    @MainActor
    func testLAuteurDUneAffaireEngageeGardeLeCrayon() throws {
        let app = lancer(["-compte", "resident"])
        let carte = app.buttons["fil.ticket_ouvert:41"]
        XCTAssertTrue(carte.apparait())
        carte.tap()
        XCTAssertTrue(app.attendreDetailAffaire("A-0041"))
        app.elementAcces("affaire.modifier").tap()
        XCTAssertTrue(app.elementAcces("modifier.contenuFige").apparait())
        let titreFige = NSPredicate(format: "identifier == %@ AND isEnabled == false", "modifier.titre")
        XCTAssertTrue(
            app.descendants(matching: .any).matching(titreFige).firstMatch.exists, "le titre ne se modifie plus")
    }

    /// Le conseil syndical : 🔗 · 🔄 · options · 📦, sans « Répondre » ; une Suite qui
    /// change l'état rejoint l'Historique, l'archivage retire 📦.
    @MainActor
    func testLeConseilSuitEtArchiveDepuisLeBandeau() throws {
        let app = lancer()
        let carte = app.buttons["fil.ticket_ouvert:41"]
        XCTAssertTrue(carte.apparait())
        carte.tap()
        XCTAssertTrue(app.attendreDetailAffaire("A-0041"))
        let suite = app.elementAcces("affaire.suite")
        XCTAssertTrue(suite.exists)
        XCTAssertTrue(app.elementAcces("affaire.options").exists)
        XCTAssertFalse(app.elementAcces("affaire.repondre").exists, "le conseil ne répond pas, il suit")
        XCTAssertTrue(app.elementAcces("affaire.message.503").exists, "la note interne, au conseil")

        suite.tap()
        let texte = app.elementAcces("suite.texte")
        XCTAssertTrue(texte.apparait())
        texte.tap()
        texte.typeText("Le plombier est passé.")
        app.elementAcces("suite.enregistrer").tap()
        let ajoutee = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Le plombier est passé.")).firstMatch
        XCTAssertTrue(ajoutee.apparait(), "la suite rejoint l'Historique")

        app.elementAcces("affaire.archiver").tap()
        let archivee = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Affaire archivée")).firstMatch
        XCTAssertTrue(archivee.apparait())
        XCTAssertFalse(app.elementAcces("affaire.archiver").exists)
    }

    /// ✏️ (#91) : la feuille part de l'affaire servie, n'enregistre qu'un changement, et
    /// l'affaire relue le montre.
    @MainActor
    func testLeConseilModifieLAffaireDepuisLeBandeau() throws {
        let app = lancer()
        let carte = app.buttons["fil.ticket_ouvert:41"]
        XCTAssertTrue(carte.apparait())
        carte.tap()
        XCTAssertTrue(app.attendreDetailAffaire("A-0041"))
        let modifier = app.elementAcces("affaire.modifier")
        XCTAssertTrue(modifier.exists)
        modifier.tap()

        let titre = app.textFields["modifier.titre"]
        XCTAssertTrue(titre.apparait())
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
        XCTAssertTrue(modifiee.apparait(), "le nouveau titre, relu")
    }

    /// ✏️ selon la saisie du compte (#110), comme la Création : A-0041 est un sinistre urgent
    /// (l'urgence y est essentielle). Passée en question, son urgence se range dans « Plus de
    /// détails », qui s'ouvre d'office puisqu'elle porte une valeur ; en Complète, tout reste
    /// à son rang.
    @MainActor
    func testLaModificationSuitLaSaisieDuCompte() throws {
        for (arguments, essentielle) in [([String](), true), (["-saisie", "complete"], false)] {
            let app = lancer(arguments)
            let carte = app.buttons["fil.ticket_ouvert:41"]
            XCTAssertTrue(carte.apparait())
            carte.tap()
            XCTAssertTrue(app.attendreDetailAffaire("A-0041"))
            app.elementAcces("affaire.modifier").tap()

            let mode = app.elementAcces("modifier.modeSaisie")
            XCTAssertTrue(mode.apparait(), "la phrase dit la saisie")
            XCTAssertTrue(mode.label.contains(essentielle ? "Saisie essentielle" : "Saisie complète"), mode.label)
            XCTAssertFalse(app.elementAcces("modifier.plusDeDetails").exists, "l'urgence d'un sinistre est à son rang")

            let question = app.elementAcces("nouvelle.categorie.question")
            XCTAssertTrue(question.apparait())
            // Les vignettes en grille : « Question » peut être sous le pli.
            for _ in 0..<6 where !question.isHittable { app.swipeUp() }
            question.tap()
            let groupe = app.elementAcces("modifier.plusDeDetails")
            if essentielle {
                XCTAssertTrue(groupe.apparait(), "l'urgence d'une question se range")
                let urgente = app.elementAcces("modifier.urgente")
                for _ in 0..<6 where !(urgente.exists && urgente.isHittable) { app.swipeUp() }
                XCTAssertTrue(urgente.exists, "le groupe s'ouvre d'office : l'urgence porte une valeur")
                LancementCaptures.capturer("modifier-essentielle-plus-de-details")
            } else {
                XCTAssertFalse(groupe.exists, "en Complète, rien ne se range")
            }
            app.terminate()
        }
    }

    /// #98 : un détail servi en 8 s — bien plus que les 5 s qu'attendaient ces tests — se lit
    /// quand même, bandeau compris : on attend le détail chargé, jamais une durée.
    @MainActor
    func testUnDetailLentSAttendJusquASonBandeau() throws {
        let app = lancer(["-delai-detail", "8000"])
        let carte = app.buttons["fil.ticket_ouvert:41"]
        XCTAssertTrue(carte.apparait())
        carte.tap()
        XCTAssertTrue(app.attendreDetailAffaire("A-0041"))
        XCTAssertTrue(app.elementAcces("affaire.suite").exists)
        XCTAssertTrue(app.elementAcces("affaire.message.503").exists)
    }

    @MainActor
    func testUnSondageUnDocumentEtUnResumeSOuvrent() throws {
        let app = lancer()
        let sondage = app.buttons["fil.sondage_ouvert:3"]
        XCTAssertTrue(sondage.apparait())
        sondage.tap()
        XCTAssertTrue(app.elementAcces("sondage.option.1").apparait())
        app.navigationBars.buttons.firstMatch.tap()

        let document = app.buttons["fil.document:7"]
        XCTAssertTrue(document.apparait())
        document.tap()
        XCTAssertTrue(app.navigationBars["Procès-verbal de l'assemblée générale"].apparait())
        app.navigationBars.buttons.firstMatch.tap()

        let point = app.buttons["fil.point_conseil:2"]
        if !point.isHittable { app.swipeUp() }
        XCTAssertTrue(point.apparait())
        point.tap()
        XCTAssertTrue(
            app.staticTexts["Ordre du jour : ascenseur, ravalement, contrat d'entretien."].apparait())
    }
}
