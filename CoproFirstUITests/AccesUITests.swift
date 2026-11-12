// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// « Mes lots & accès » (#13), sur l'API simulée : chaque onglet s'ouvre, et les
/// gestes d'accès aboutissent. Chaque étape joint sa capture (gardée dans le
/// résultat du test : ce sont les captures de la PR).
///
/// ⚠️ Un élément se cherche par son IDENTIFIANT ou son libellé, jamais par son type
/// (`app.buttons`, `app.links`…) : le type d'accessibilité diffère d'une version
/// d'iOS à l'autre (poste en iOS 27, CI en iOS 26 — leçon de #12).
///
/// ⚠️ Aucune attente n'a son propre délai : toutes rendent la main dès que l'état est
/// là, au plus tard au plafond commun (`Attente.plafond`, #123). Et l'avis qui suit un
/// geste (« Accès enregistré ») dure 4 s dans l'app : il se lit sous `-avis-durable`,
/// qui le garde à l'écran — sur le runner, deux requêtes d'accessibilité expirées
/// d'affilée (57,8 s) l'ont laissé repartir avant d'être lu (run 43060065387). La
/// preuve du geste reste l'état durable qui le suit : l'accès perdu ne se signale
/// plus, le code déclaré est dans la liste relue.
final class AccesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func ouvrirAcces() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil", "-avis-durable"]
        app.launch()
        let barre = app.tabBars.firstMatch
        XCTAssertTrue(barre.apparait())
        barre.buttons["Accès"].tap()
        XCTAssertTrue(app.navigationBars["Mes lots & accès"].apparait())
        return app
    }

    @MainActor
    func testLesQuatreOngletsSOuvrent() throws {
        let app = ouvrirAcces()
        XCTAssertTrue(app.libelleAcces("Caractéristiques").apparait(), "la carte du lot")
        app.capturerAcces("acces-1-mes-lots", dans: self)

        app.elementAcces("acces.lot.417").tap()
        XCTAssertTrue(app.libelleAcces("Sous-sol A").apparait(), "le lot choisi s'affiche")

        app.elementAcces("onglet.badges").tap()
        XCTAssertTrue(app.libelleAcces("A4F21C07").apparait(), "les badges détenus")
        app.capturerAcces("acces-2-badges", dans: self)

        app.elementAcces("onglet.telecommandes").tap()
        XCTAssertTrue(app.libelleAcces("TC-2048").apparait(), "les télécommandes détenues")
        app.capturerAcces("acces-3-telecommandes", dans: self)

        // Le compte simulé est au conseil syndical : la gestion locative lui est ouverte.
        app.elementAcces("onglet.telecommandes").swipeLeft()
        app.elementAcces("onglet.location").tap()
        XCTAssertTrue(app.libelleAcces("Locataire DU LOT 31").apparait(), "un bail actif")
        app.capturerAcces("acces-4-gestion-locative", dans: self)
        app.libelleAcces("📁 Archives").tap()
        XCTAssertTrue(app.libelleAcces("Ancien locataire DU LOT 31").apparait(), "les archives")
    }

    @MainActor
    func testSignalerPerduPuisDeclarer() throws {
        let app = ouvrirAcces()
        app.elementAcces("onglet.badges").tap()
        let perdu = app.elementAcces("acces.perdu.12")
        XCTAssertTrue(perdu.apparait())
        perdu.tap()
        app.elementAcces("acces.perdu.confirmer").tap()
        XCTAssertTrue(app.libelleAcces("Signalement enregistré").apparait())
        XCTAssertFalse(app.elementAcces("acces.perdu.12").exists, "un accès perdu ne se signale plus")

        app.elementAcces("acces.gestes").tap()
        app.elementAcces("acces.geste.declarer").tap()
        let code = app.elementAcces("acces.declarer.code")
        XCTAssertTrue(code.apparait())
        code.typeText("TC-7777")
        app.capturerAcces("acces-5-declarer", dans: self)
        app.elementAcces("acces.feuille.enregistrer").tap()
        XCTAssertTrue(app.libelleAcces("Accès enregistré").apparait())
        app.elementAcces("onglet.telecommandes").tap()
        XCTAssertTrue(app.libelleAcces("TC-7777").apparait(), "la liste est relue")
    }

    @MainActor
    func testNouvelAccesNeProposeQueSesLots() throws {
        let app = ouvrirAcces()
        app.elementAcces("onglet.badges").tap()
        app.elementAcces("acces.gestes").tap()
        app.elementAcces("acces.geste.demander").tap()
        XCTAssertTrue(app.navigationBars["Nouvelle demande d'accès"].apparait())
        app.elementAcces("acces.feuille.enregistrer").tap()
        XCTAssertTrue(app.libelleAcces("Sélectionnez un lot").apparait(), "un lot est exigé")
        app.elementAcces("acces.demande.lot").tap()
        XCTAssertTrue(app.libelleAcces("Lot 15").apparait())
        XCTAssertTrue(app.libelleAcces("Lot 450").exists)
        app.libelleAcces("Lot 15").tap()
        app.capturerAcces("acces-6-nouvel-acces", dans: self)
        app.elementAcces("acces.feuille.enregistrer").tap()
        let avis = app.libelleAcces("Demande envoyée au conseil syndical")
        XCTAssertTrue(avis.apparait())
        // Le garde-fou de `-avis-durable` : passé les 4 s de l'app, l'avis est toujours là.
        // Sans lui, les avis de ces tests se liraient de nouveau contre la montre.
        XCTAssertTrue(avis.demeure(6), "sous -avis-durable, l'avis ne se retire pas")
    }
}

/// La recherche des tests d'interface de #13 (Accès, Prestataires) : par identifiant
/// ou par libellé, quel que soit le type de l'élément.
extension XCUIApplication {
    func elementAcces(_ identifiant: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifiant).firstMatch
    }

    /// Le premier élément dont le libellé COMMENCE par ce texte (une carte réunit
    /// souvent plusieurs textes en un seul libellé).
    func libelleAcces(_ debut: String) -> XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", debut)).firstMatch
    }

    /// Un élément de cet identifiant qui DIT `texte`, dans son libellé ou sa valeur — à
    /// attendre par `apparait()` ou à lire par `sonde()`. Tous les éléments de
    /// l'identifiant sont lus : il peut être porté par un conteneur muet (#11).
    func elementDisant(_ identifiant: String, _ texte: String) -> XCUIElement {
        let predicat = NSPredicate(
            format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)", identifiant, texte, texte)
        return descendants(matching: .any).matching(predicat).firstMatch
    }

    /// « Plus », puis l'entrée de ce libellé. Aux grandes tailles, la ligne est sous le pli :
    /// la liste ne la crée qu'au défilement.
    @MainActor
    func ouvrirDansPlus(_ libelle: String) {
        let plus = descendants(matching: .any)["Plus"].firstMatch
        XCTAssertTrue(plus.apparait())
        plus.tap()
        let entree = libelleAcces(libelle)
        _ = entree.sonde()
        for _ in 0..<6 where !(entree.exists && entree.isHittable) { swipeUp() }
        XCTAssertTrue(entree.exists, "« \(libelle) » dans Plus")
        entree.tap()
    }

    @MainActor
    func capturerAcces(_ nom: String, dans test: XCTestCase) {
        let piece = XCTAttachment(screenshot: screenshot())
        piece.name = nom
        piece.lifetime = .keepAlways
        test.add(piece)
    }
}
