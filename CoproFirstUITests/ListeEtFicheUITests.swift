// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// La liste et la fiche côte à côte, sur iPad en plein écran et EN PAYSAGE — classe de
/// taille régulière (#222) : la fiche s'ouvre à droite, la liste reste, sa carte soulignée.
/// En portrait, deux colonnes seulement : la barre et la page, la fiche poussée par-dessus
/// la liste comme sur l'iPhone (`ClasseDeLaPage`) — `testEnPortrait…`.
///
/// Sautés sur iPhone : le test choisit son appareil, l'app ne lit que la classe de taille
/// et la forme de la fenêtre. Sur iPhone, les tests d'Affaires et du Fil prouvent la pile.
final class ListeEtFicheUITests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "liste et fiche : iPad en plein écran")
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    /// Le simulateur rendu en portrait : les classes suivantes l'attendent ainsi.
    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    private func lancer(_ ecran: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", ecran]
        app.launch()
        return app
    }

    /// Le rendu, gardé au résultat du passage : la PR le montre (`xcresulttool export attachments`).
    private func capture(_ nom: String, _ app: XCUIApplication) {
        let piece = XCTAttachment(screenshot: app.screenshot())
        piece.name = nom
        piece.lifetime = .keepAlways
        add(piece)
    }

    /// La fiche d'une affaire, chargée, dans la colonne de fiche : sans barre à elle, son
    /// numéro est dans l'en-tête (`affaire.numero`), et son bandeau au bas de la colonne.
    private func ficheAffaire(_ numero: String, dans app: XCUIApplication) -> Bool {
        let numero = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'affaire.numero' AND label == %@", numero)).firstMatch
        return numero.apparait() && app.elementAcces("affaire.lien").apparait()
    }

    @MainActor
    func testUneAffaireSOuvreACoteDeLaListe() throws {
        let app = lancer("affaires")
        app.toucher(app.elementAcces("barre.mes-demandes"))
        XCTAssertTrue(app.staticTexts["Aucune sélection"].apparait(), "rien de choisi : la fiche vide")

        app.toucher(app.elementAcces("affaires.carte.A-0041"))
        XCTAssertTrue(ficheAffaire("A-0041", dans: app))
        XCTAssertTrue(app.elementAcces("affaires.carte.A-0040").exists, "la liste reste à côté")
        XCTAssertTrue(app.navigationBars["Mes affaires"].exists, "la page garde son titre")
        // Le bandeau est au bas de la colonne de la fiche, pas sous la liste.
        let lien = app.elementAcces("affaire.lien").frame
        let liste = app.elementAcces("affaires.carte.A-0040").frame
        XCTAssertGreaterThan(lien.minX, liste.maxX, "le bandeau sous la fiche, à droite de la liste")
        XCTAssertGreaterThan(lien.minY, liste.minY, "au bas de la colonne")
        XCTAssertTrue(app.elementRetenu("affaires.carte.A-0041").apparait(), "sa carte est soulignée")
        capture("affaires-liste-et-fiche", app)

        // Une autre affaire dont l'API simulée sert le détail (FixturesDetailAffaire).
        app.toucher(app.elementAcces("affaires.carte.A-0038"))
        XCTAssertTrue(ficheAffaire("A-0038", dans: app), "une autre carte remplace la fiche")
        XCTAssertTrue(app.elementRetenu("affaires.carte.A-0038").apparait())
    }

    /// La page se reconstruit quand on la quitte (barre latérale), comme au pli d'un iPhone
    /// pliable : l'affaire ouverte se retrouve au retour (`MemoireDesSelections`, #119).
    @MainActor
    func testLAffaireOuverteSeRetrouveEnRevenantALaPage() throws {
        let app = lancer("affaires")
        app.toucher(app.elementAcces("barre.mes-demandes"))
        app.toucher(app.elementAcces("affaires.carte.A-0041"))
        XCTAssertTrue(ficheAffaire("A-0041", dans: app))

        app.toucher(app.elementAcces("barre.faq"))
        XCTAssertTrue(app.navigationBars["FAQ"].apparait())
        app.toucher(app.elementAcces("barre.mes-demandes"))
        XCTAssertTrue(ficheAffaire("A-0041", dans: app), "la fiche ouverte au départ, sans clignement vide")
        XCTAssertTrue(app.elementRetenu("affaires.carte.A-0041").apparait(), "sa carte toujours soulignée")
    }

    @MainActor
    func testLeFilGardeSaListeAuToucherDUneCarte() throws {
        let app = lancer("fil")
        let affaire = app.buttons["fil.ticket_ouvert:41"]
        app.toucher(affaire)
        XCTAssertTrue(ficheAffaire("A-0041", dans: app))
        XCTAssertTrue(affaire.exists, "le fil reste à côté")
        XCTAssertTrue(app.navigationBars["Fil d'activité"].exists, "le fil garde son titre")
        XCTAssertTrue(app.elementRetenu("fil.ticket_ouvert:41").apparait())
        capture("fil-liste-et-fiche", app)

        app.toucher(app.buttons["fil.sondage_ouvert:3"])
        // La question, en tête de fiche : les résultats provisoires passent au-dessus du vote (#257).
        XCTAssertTrue(app.elementAcces("sondage.question").apparait(), "le sondage remplace l'affaire")
        XCTAssertTrue(affaire.exists)
    }

    /// La Résidence : le syndic de la Fiche ouvre l'annuaire à côté, la Fiche reste.
    @MainActor
    func testLeSyndicSOuvreACoteDeLaFicheDeLaResidence() throws {
        let app = lancer("fil")
        app.toucher(app.elementAcces("barre.residence"))
        let syndic = app.elementAcces("residence.syndic")
        app.toucher(syndic)
        let appeler = app.elementAcces("annuaire.appeler")
        XCTAssertTrue(appeler.apparait(), "l'annuaire du syndic dans la colonne")
        XCTAssertTrue(app.staticTexts["AA0-000-000"].exists, "la Fiche reste à côté")
        XCTAssertGreaterThan(appeler.frame.minX, syndic.frame.maxX, "à droite de la Fiche")
        XCTAssertTrue(app.elementRetenu("residence.syndic").apparait(), "le syndic est souligné")
        XCTAssertEqual(
            app.buttons.matching(identifier: "pastille.residence").count, 1,
            "la pastille de la page, pas une seconde pour la fiche")
        capture("residence-liste-et-fiche", app)

        // Un autre onglet : la fiche d'à côté n'est plus la sienne.
        app.toucher(app.buttons["Carnet d’entretien"])
        XCTAssertTrue(app.staticTexts["Aucune sélection"].apparait(), "l'onglet change, la fiche se vide")
    }

    /// Une rangée de `List` (les annonces) : l'annonce à côté, la liste gardée.
    @MainActor
    func testUneAnnonceSOuvreACoteDeSaListe() throws {
        let app = lancer("fil")
        app.toucher(app.elementAcces("barre.communaute"))
        app.toucher(app.elementAcces("communaute.onglet.annonces"))
        let annonce = app.elementAcces("annonce.21")
        app.toucher(annonce)
        let contact = app.elementAcces("annonce.contact")
        XCTAssertTrue(contact.apparait(), "l'annonce dans la colonne")
        XCTAssertTrue(annonce.exists, "la liste reste à côté")
        XCTAssertGreaterThan(contact.frame.minX, annonce.frame.maxX, "à droite de la liste")
        XCTAssertTrue(app.elementRetenu("annonce.21").apparait(), "sa rangée est soulignée")
        // Le titre en tête, iOS 26 retirait l'action de gauche : elle passe à droite (#223).
        XCTAssertTrue(app.elementAcces("communaute.creer").apparait(), "« Créer » reste dans la barre")
        capture("annonces-liste-et-fiche", app)
    }

    /// Un document à côté du fil porte son titre en tête : la colonne de fiche n'a pas de
    /// barre à elle, et l'aperçu du système n'en montre aucun (#223).
    @MainActor
    func testUnDocumentACoteDuFilPorteSonTitre() throws {
        let app = lancer("fil")
        let document = app.buttons["fil.document:7"]
        app.toucher(document)
        XCTAssertTrue(app.elementAcces("document.titre").apparait(), "le titre en tête de la colonne")
        XCTAssertTrue(document.exists, "le fil reste à côté")
        capture("fil-document-a-cote", app)
    }

    /// En portrait, trois colonnes étaient illisibles : la liste prend la page, la fiche
    /// passe par-dessus — son numéro au titre de la barre, comme sur l'iPhone — et le
    /// retour rend la liste. La barre latérale reste à côté.
    @MainActor
    func testEnPortraitLaFicheSOuvreParDessusLaListe() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = lancer("affaires")
        app.toucher(app.elementAcces("barre.mes-demandes"))
        let carte = app.elementAcces("affaires.carte.A-0041")
        XCTAssertTrue(carte.apparait())
        XCTAssertFalse(app.staticTexts["Aucune sélection"].exists, "pas de colonne de fiche en portrait")
        XCTAssertTrue(app.elementAcces("barre.faq").exists, "la barre latérale reste à côté")
        capture("affaires-portrait-liste", app)

        app.toucher(carte)
        XCTAssertTrue(app.navigationBars["A-0041"].apparait(), "la fiche poussée, son numéro en barre")
        XCTAssertTrue(app.elementAcces("affaire.lien").apparait())
        XCTAssertFalse(app.elementAcces("affaires.carte.A-0040").exists, "la liste est sous la fiche")
        capture("affaires-portrait-fiche", app)

        // Le clavier d'une feuille ne fait pas passer le portrait pour un paysage : la fiche
        // poussée reste sous la saisie, et après.
        app.toucher(app.elementAcces("affaire.repondre"))
        let texte = app.elementAcces("repondre.texte")
        XCTAssertTrue(texte.apparait())
        texte.typeText("Merci.")
        app.toucher(app.elementAcces("repondre.envoyer"))
        XCTAssertTrue(app.elementAcces("affaire.repondre").apparait(), "la feuille se referme sur la fiche")
        XCTAssertTrue(app.navigationBars["A-0041"].exists, "la fiche est restée poussée")

        app.toucher(app.navigationBars["A-0041"].buttons.firstMatch)
        XCTAssertTrue(app.elementAcces("affaires.carte.A-0040").apparait(), "le retour rend la liste")
    }

    /// Le fil en portrait : la carte touchée ouvre sa fiche par-dessus le fil.
    @MainActor
    func testEnPortraitLeFilPousseSaFiche() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = lancer("fil")
        let affaire = app.buttons["fil.ticket_ouvert:41"]
        XCTAssertTrue(affaire.apparait())
        capture("fil-portrait", app)
        app.toucher(affaire)
        XCTAssertTrue(app.navigationBars["A-0041"].apparait(), "la fiche poussée par-dessus le fil")
        XCTAssertFalse(affaire.exists, "le fil est sous la fiche")
    }
}
