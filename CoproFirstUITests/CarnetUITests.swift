// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Le carnet de l'iPhone pliable ouvert (#119) : les intercalaires sur la tranche droite, à
/// la place de la barre du bas. Joué en classe régulière, la charnière fixée par
/// `-posture deplie` : un simulateur iPad sert au poste comme en CI, qui n'a ni iOS 27.1 ni
/// l'iPhone Duo. Sur l'iPhone Duo déplié, la vraie charnière se lit, au poste seulement.
///
/// La semaine du Fil (#277) et le sommaire de la résidence (#278) s'y jouent aussi.
///
/// Sautés sur iPhone (classe compacte) : le test choisit son appareil, l'app, elle, ne lit
/// que la classe de taille et la charnière (`PresentationNavigation.pour`).
final class CarnetUITests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "le carnet : classe régulière")
    }

    private func lancer(_ arguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil", "-posture", "deplie"] + arguments
        app.launch()
        return app
    }

    private func intercalaire(_ id: String, dans app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "carnet.\(id)").firstMatch
    }

    /// Toutes les pages en intercalaires, dans l'ordre réglé, sans « Plus » ni barre latérale ;
    /// un toucher ouvre la page, et l'intercalaire ouvert se dit retenu.
    @MainActor
    func testLesIntercalairesOuvrentToutesLesPages() throws {
        let app = lancer()
        let ids = ["tableau-de-bord", "residence", "mes-demandes", "mon-lot", "annuaire", "faq", "profil", "a-propos"]
        for id in ids {
            XCTAssertTrue(intercalaire(id, dans: app).apparait(), "« \(id) » en intercalaire")
        }
        let barre = app.descendants(matching: .any).matching(identifier: "barre.faq").firstMatch
        XCTAssertFalse(barre.sonde(), "pas de barre latérale : le carnet la remplace")
        XCTAssertEqual(intercalaire("mon-lot", dans: app).label, "Accès", "le libellé de la barre, écrit une fois")

        app.toucher(intercalaire("faq", dans: app))
        XCTAssertTrue(app.navigationBars["FAQ"].apparait(), "une page d'au-delà de la barre du bas, d'un toucher")
        XCTAssertTrue(app.elementRetenu("carnet.faq").apparait(), "l'intercalaire ouvert est retenu")

        app.toucher(intercalaire("profil", dans: app))
        XCTAssertTrue(app.navigationBars["Profil"].apparait())
        XCTAssertTrue(app.buttons["pastille.residence"].apparait(), "« où suis-je » sur chaque page du carnet")
    }

    /// Le Fil, une journée par double page : la veille et le lendemain se tournent, la carte
    /// choisie s'ouvre sur la page de droite. Aujourd'hui, pas de lendemain.
    @MainActor
    func testLeFilSeLitUneJourneeParDoublePage() throws {
        let app = lancer()
        let veille = app.elementAcces("carnet.veille")
        XCTAssertTrue(veille.apparait(), "le pied de page du jour")
        let lendemainInactif = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND isEnabled == false", "carnet.lendemain")).firstMatch
        XCTAssertTrue(lendemainInactif.apparait(), "aujourd'hui : pas de lendemain")
        let duJour = app.buttons["fil.ticket_ouvert:41"]
        XCTAssertTrue(duJour.apparait(), "les cartes du jour")

        app.toucher(veille)
        let dHier = app.buttons["fil.sondage_ouvert:3"]
        XCTAssertTrue(dHier.apparait(), "la veille : ses cartes")
        XCTAssertTrue(duJour.disparait(), "une journée à la fois")
        app.toucher(dHier)
        XCTAssertTrue(app.elementAcces("sondage.option.1").apparait(), "la fiche sur la page de droite")

        app.toucher(app.elementAcces("carnet.lendemain"))
        XCTAssertTrue(duJour.apparait(), "le lendemain ramène aujourd'hui")
    }

    /// Un élément demandé au lancement (une notification touchée, `-ouvrir`) s'ouvre sur la
    /// page de son jour, même quand le carnet reconstruit le Fil au lancement : la charnière
    /// arrive après le premier écran (#119).
    @MainActor
    func testUnElementDemandeAuLancementSOuvreSurLaPageDeSonJour() throws {
        let app = lancer("-ouvrir", "sondage_ouvert:3")
        XCTAssertTrue(app.elementAcces("sondage.option.1").apparait(), "la fiche demandée, à droite")
        XCTAssertTrue(app.buttons["fil.sondage_ouvert:3"].apparait(), "la page de son jour, à gauche")
        let lendemain = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND isEnabled == true", "carnet.lendemain")).firstMatch
        XCTAssertTrue(lendemain.apparait(), "la veille d'aujourd'hui : le lendemain se tourne")
    }

    /// La semaine (#277) : PINCER la page du jour l'ouvre sur toute la double page, chaque
    /// carte à son jour ; ÉCARTER les doigts sur un jour ramène sa page ; une carte touchée
    /// dans la semaine s'ouvre sur la page de son jour.
    @MainActor
    func testPincerOuvreLaSemaineEtEcarterRameneAuJour() throws {
        let app = lancer()
        let pageDuJour = app.elementAcces("carnet.jour")
        XCTAssertTrue(pageDuJour.apparait(), "la page du jour")
        pageDuJour.pinch(withScale: 0.4, velocity: -1)

        let semaine = app.elementAcces("carnet.semaine")
        XCTAssertTrue(semaine.apparait(), "pincer : la semaine")
        let aujourdhui = app.elementAcces("carnet.semaine.\(Self.aujourdhuiISO)")
        XCTAssertTrue(aujourdhui.apparait(), "aujourd'hui, dans sa semaine")
        let duJour = app.buttons["fil.ticket_ouvert:41"]
        XCTAssertTrue(duJour.apparait(), "les cartes, à leur jour")
        XCTAssertTrue(app.elementAcces("carnet.semaine.precedente").apparait(), "le pied de page de la semaine")
        XCTAssertTrue(app.elementAcces("carnet.veille").disparait(), "plus de page du jour")

        aujourdhui.pinch(withScale: 2.5, velocity: 1)
        XCTAssertTrue(app.elementAcces("carnet.veille").apparait(), "écarter : la page du jour")
        XCTAssertTrue(semaine.disparait())

        app.elementAcces("carnet.jour").pinch(withScale: 0.4, velocity: -1)
        XCTAssertTrue(semaine.apparait(), "la semaine, de nouveau")
        app.toucher(duJour)
        XCTAssertTrue(app.elementAcces("carnet.veille").apparait(), "une carte touchée : la page de son jour")
        XCTAssertTrue(semaine.disparait())
    }

    /// Le jour d'aujourd'hui tel que l'app l'écrit (`jourISO`, à Paris).
    private static var aujourdhuiISO: String {
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.timeZone = TimeZone(identifier: "Europe/Paris")
        format.dateFormat = "yyyy-MM-dd"
        return format.string(from: .now)
    }

    /// Ma résidence (#278) : le sommaire à gauche — les rubriques de la Fiche, puis le
    /// Carnet d'entretien et le Règlement —, la page choisie à droite. La première s'ouvre
    /// d'elle-même ; les onglets disparaissent, le sommaire les remplace.
    @MainActor
    func testLesDocumentsDeLaResidenceEnDoublePage() throws {
        let app = lancer()
        app.toucher(intercalaire("residence", dans: app))
        XCTAssertTrue(app.elementAcces("residence.sommaire.rubrique.identite").apparait(), "le sommaire, à gauche")
        XCTAssertTrue(app.elementRetenu("residence.sommaire.rubrique.identite").apparait(), "la première page, ouverte")
        XCTAssertTrue(app.staticTexts["AA0-000-000"].apparait(), "la Fiche, à droite")
        XCTAssertFalse(app.elementAcces("residence.onglets").sonde(), "pas d'onglets : le sommaire")

        app.toucher(app.elementAcces("residence.sommaire.onglet.carnet"))
        XCTAssertTrue(app.staticTexts["Révision annuelle de la chaudière"].apparait(), "le carnet d'entretien")
        XCTAssertTrue(app.elementRetenu("residence.sommaire.onglet.carnet").apparait())

        app.toucher(app.elementAcces("residence.sommaire.onglet.reglement"))
        XCTAssertTrue(
            app.staticTexts["Puis-je installer une climatisation sur mon balcon ?"].apparait(),
            "le Règlement et ses questions")
        XCTAssertTrue(app.elementAcces("residence.sommaire.rubrique.plans").exists, "le sommaire reste")
    }

    /// Une page renommée par l'administration garde son nom sur la tranche aussi.
    @MainActor
    func testUnePageRenommeeGardeSonNomSurLaTranche() throws {
        let app = lancer("-page-renommee")
        let page = intercalaire("mon-lot", dans: app)
        XCTAssertTrue(page.apparait())
        XCTAssertEqual(page.label, "Clés et badges")
    }
}
