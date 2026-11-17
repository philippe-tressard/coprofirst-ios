// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// La liste et la fiche côte à côte, sur iPad en plein écran — classe de taille régulière
/// (#222) : la fiche s'ouvre à droite, la liste reste, sa carte soulignée.
///
/// Sautés sur iPhone : le test choisit son appareil, l'app ne lit que la classe de taille
/// (`ListeEtFiche`). Sur iPhone, les tests d'Affaires et du Fil prouvent la pile d'avant.
final class ListeEtFicheUITests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "liste et fiche : iPad en plein écran")
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

    private func choisie(_ identifiant: String, dans app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND isSelected == true", identifiant)).firstMatch
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
        XCTAssertTrue(choisie("affaires.carte.A-0041", dans: app).apparait(), "sa carte est soulignée")
        capture("affaires-liste-et-fiche", app)

        // Une autre affaire dont l'API simulée sert le détail (FixturesDetailAffaire).
        app.toucher(app.elementAcces("affaires.carte.A-0038"))
        XCTAssertTrue(ficheAffaire("A-0038", dans: app), "une autre carte remplace la fiche")
        XCTAssertTrue(choisie("affaires.carte.A-0038", dans: app).apparait())
    }

    @MainActor
    func testLeFilGardeSaListeAuToucherDUneCarte() throws {
        let app = lancer("fil")
        let affaire = app.buttons["fil.ticket_ouvert:41"]
        app.toucher(affaire)
        XCTAssertTrue(ficheAffaire("A-0041", dans: app))
        XCTAssertTrue(affaire.exists, "le fil reste à côté")
        XCTAssertTrue(app.navigationBars["Fil d'activité"].exists, "le fil garde son titre")
        XCTAssertTrue(choisie("fil.ticket_ouvert:41", dans: app).apparait())
        capture("fil-liste-et-fiche", app)

        app.toucher(app.buttons["fil.sondage_ouvert:3"])
        XCTAssertTrue(app.elementAcces("sondage.option.1").apparait(), "le sondage remplace l'affaire")
        XCTAssertTrue(affaire.exists)
    }
}
