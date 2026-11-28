// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Le Fil en tuiles de l'écran de hall (#429), au simulateur Apple TV, sur le serveur simulé :
/// la grille, la mise en avant tenue, le mouvement réduit, le clic de la télécommande, le fond
/// clair sous le thème sombre, le grand texte. Aucun test n'attend la cadence (20 s, puis 10 s) :
/// un état passager ne s'attend pas contre la montre (skill `swiftui-patterns`, tests §4).
final class FilDuHallUITests: XCTestCase {
    /// Les tuiles de la démo ; puis celles qui ne paraissent qu'au pire cas (`-fil-plein`).
    private static let tuiles = ["urgence.ticket_ouvert:41", "epingles", "sondage.12", "idee.3", "annonce.21"]
    private static let tuilesDuPireCas = ["urgence.publication:12", "urgence.ticket_mis_a_jour:38"]

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func lancer(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-hall", "fil"] + arguments
        app.launch()
        return app
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ identifiant: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifiant).firstMatch
    }

    /// Les rangées de la maquette 5.2 : en haut l'urgence et les épinglés, au milieu la
    /// communauté, en bas le carrousel — et l'heure de l'Apple TV.
    @MainActor
    func testLaGrillePoseChaqueRangee() {
        let app = lancer()
        for tuile in Self.tuiles {
            XCTAssertTrue(element(app, "hall.tuile.\(tuile)").apparait(), "la tuile \(tuile)")
        }
        XCTAssertTrue(element(app, "hall.carrousel").apparait())
        XCTAssertTrue(element(app, "hall.heure").apparait())
        tuilesDansLEcranSansChevauchement(app)
    }

    /// Sans urgence, les épinglés prennent toute la rangée ; sans idée, la tuile est absente.
    @MainActor
    func testSansUrgenceNiIdeeAucuneCaseVide() {
        let app = lancer(["-fil-sans", "urgence,idee"])
        let epingles = element(app, "hall.tuile.epingles")
        XCTAssertTrue(epingles.apparait())
        XCTAssertGreaterThan(epingles.frame.width, app.windows.firstMatch.frame.width * 0.85)
        XCTAssertFalse(element(app, "hall.tuile.idee.3").exists)
        XCTAssertFalse(element(app, "hall.tuile.urgence.ticket_ouvert:41").exists)
        tuilesDansLEcranSansChevauchement(app)
    }

    /// Une tuile tenue agrandie (les captures) : elle couvre l'écran, avec tout son contenu.
    @MainActor
    func testUneMiseEnAvantMontreLaTuileAgrandie() {
        let app = lancer(["-mise-en-avant", "urgence.ticket_ouvert:41"])
        let avant = element(app, "hall.miseEnAvant")
        XCTAssertTrue(avant.apparait())
        XCTAssertEqual(avant.value as? String, "urgence.ticket_ouvert:41")
        XCTAssertGreaterThan(avant.frame.width, element(app, "hall.tuile.epingles").frame.width)
    }

    /// Avec le mouvement réduit, la mise en avant paraît encore — en fondu, sans agrandissement.
    /// Son cycle (s'ouvrir seule, se refermer) se prouve sans horloge : `DiffusionDuFilTests`.
    @MainActor
    func testLeMouvementReduitGardeLaMiseEnAvant() {
        let app = lancer(["-mise-en-avant", "epingles", "-mouvement-reduit"])
        let avant = element(app, "hall.miseEnAvant")
        XCTAssertTrue(avant.apparait())
        XCTAssertEqual(avant.value as? String, "epingles")
    }

    /// Un clic de la télécommande propose « Désappairer » — sur le Fil comme sur les affiches
    /// (`GestesDuHall`, écrit une fois) : c'est la seule sortie de l'écran.
    @MainActor
    func testUnClicProposeDeDesappairer() {
        for hall in ["fil", "diffusion"] {
            let app = XCUIApplication()
            app.launchArguments = ["-api-simulee", "-hall", hall]
            app.launch()
            XCTAssertTrue(element(app, "hall.residence").apparait(), hall)
            XCUIRemote.shared.press(.select)
            // Le dialogue est du système : son bouton se trouve par son identifiant, ou son libellé.
            let desappairer = app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier == %@ OR label == %@", "hall.desappairer", "Désappairer")
            ).firstMatch
            XCTAssertTrue(desappairer.apparait(), "le clic, sur « \(hall) »")
            app.terminate()
        }
    }

    /// Le fond reste clair quand l'Apple TV est en sombre : on le lit sur l'écran capturé.
    @MainActor
    func testLeFondResteClairSousLeThemeSombre() throws {
        let app = lancer(["-theme", "sombre"])
        XCTAssertTrue(element(app, "hall.tuile.epingles").apparait())
        let image = try XCTUnwrap(XCUIScreen.main.screenshot().image.cgImage)
        let luminance = try XCTUnwrap(Self.luminance(image, x: image.width / 2, y: 8))
        XCTAssertGreaterThan(luminance, 0.85, "le haut de l'écran, au-dessus de la grille")
    }

    /// Au grand texte et au pire que sert le serveur (trois urgences, cinq épinglés), chaque tuile
    /// reste dans l'écran et chez elle.
    @MainActor
    func testLeGrandTexteNeDebordePas() {
        let app = lancer(["-grand-texte", "-fil-plein"])
        XCTAssertTrue(element(app, "hall.tuile.epingles").apparait())
        tuilesDansLEcranSansChevauchement(app)
    }

    @MainActor
    private func tuilesDansLEcranSansChevauchement(
        _ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) {
        let ecran = app.windows.firstMatch.frame
        let cadres = ((Self.tuiles + Self.tuilesDuPireCas).map { "hall.tuile.\($0)" } + ["hall.carrousel"])
            .map { element(app, $0) }.filter { $0.exists }.map { $0.frame }
        for cadre in cadres {
            XCTAssertTrue(ecran.contains(cadre), "\(cadre) sort de l'écran", file: file, line: line)
        }
        for (rang, cadre) in cadres.enumerated() {
            for autre in cadres[(rang + 1)...] {
                XCTAssertFalse(
                    cadre.insetBy(dx: 1, dy: 1).intersects(autre), "\(cadre) chevauche \(autre)",
                    file: file, line: line)
            }
        }
    }

    /// La luminance (0 à 1) d'un pixel de la capture.
    @MainActor
    private static func luminance(_ image: CGImage, x: Int, y: Int) -> Double? {
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let contexte = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        contexte.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return (0.2126 * Double(pixel[0]) + 0.7152 * Double(pixel[1]) + 0.0722 * Double(pixel[2])) / 255
    }
}
