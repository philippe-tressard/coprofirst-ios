// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// La consultation hors ligne (#101) : l'appareil sans réseau au lancement, Face ID
/// passé — la dernière lecture s'ouvre, datée, et les gestes restent en place, grisés.
/// Contre l'API simulée (`-hors-ligne`) : aucune requête ne part.
final class HorsLigneUITests: XCTestCase {
    @MainActor
    private func lancer(_ lecture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "retour", "-hors-ligne", lecture]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifiant: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifiant).firstMatch
    }

    /// Un contrôle de cet identifiant est-il dans cet état ? Tous les éléments de
    /// l'identifiant sont interrogés : sous iOS 26.5, le premier est un conteneur toujours actif.
    private func controle(_ app: XCUIApplication, _ identifiant: String, actif: Bool) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND isEnabled == \(actif ? "true" : "false")", identifiant))
            .firstMatch
    }

    @MainActor
    func testSansReseauFaceIDOuvreLaDerniereLectureEtDitDOuElleVient() throws {
        let app = lancer("gardee")
        XCTAssertTrue(app.staticTexts["Fuite d'eau au plafond du parking"].apparait(), "le fil gardé")
        let bandeau = element(app, "horsligne.bandeau")
        XCTAssertTrue(bandeau.apparait(), "l'état se lit en haut, sans alerte")
        XCTAssertTrue(bandeau.label.contains("Hors ligne — à jour au 10/11/2026 à 14:32"), bandeau.label)
        XCTAssertTrue(bandeau.label.contains("Consultation seule"), "et pourquoi les gestes sont grisés")
        XCTAssertFalse(app.alerts.firstMatch.exists, "aucune alerte modale")
    }

    @MainActor
    func testLesGestesGardentLeurPlaceGrisesEtLaLectureResteOuverte() throws {
        let app = lancer("gardee")
        let onglet = app.descendants(matching: .any)["Affaires"].firstMatch
        XCTAssertTrue(onglet.apparait())
        onglet.tap()

        let carte = element(app, "affaires.carte.A-0041")
        XCTAssertTrue(carte.apparait(), "la liste gardée")
        XCTAssertTrue(element(app, "horsligne.bandeau").exists, "le bandeau suit d'écran en écran")
        XCTAssertTrue(controle(app, "affaires.nouvelle", actif: false).exists, "« Nouvelle affaire » en place, grisée")

        carte.tap()
        XCTAssertTrue(app.attendreDetailAffaire("A-0041"), "le détail gardé s'ouvre")
        XCTAssertTrue(element(app, "horsligne.bandeau").exists)
        XCTAssertTrue(controle(app, "affaire.suite", actif: false).exists, "« Ajouter une suite » en place, grisée")
        XCTAssertTrue(controle(app, "affaire.modifier", actif: false).exists, "« Modifier » aussi")
        XCTAssertTrue(controle(app, "affaire.lien", actif: true).exists, "copier le lien n'a pas besoin du serveur")
    }

    @MainActor
    func testSeDeconnecterHorsLigneNeLaissePlusRienALire() throws {
        let app = lancer("gardee")
        let pastille = element(app, "pastille.residence")
        XCTAssertTrue(pastille.apparait())
        pastille.tap()
        let sortir = element(app, "residence.deconnecter")
        XCTAssertTrue(sortir.apparait(), "se déconnecter reste possible sans réseau")
        sortir.tap()
        // La feuille d'action expose son bouton deux fois (feuille et menu) : le premier.
        let confirmer = element(app, "sortie.confirmer")
        XCTAssertTrue(confirmer.apparait())
        confirmer.tap()

        XCTAssertTrue(element(app, "connexion.residence").apparait(), "retour à la connexion")
        XCTAssertFalse(app.tabBars.firstMatch.exists, "plus rien de la résidence n'est affiché")
        XCTAssertFalse(element(app, "retour.ouvrir").exists, "ni session ni lecture à rouvrir")
    }

    @MainActor
    func testUneLectureTropAncienneEstEffaceeEtLAppLeDit() throws {
        let app = lancer("perimee")
        let avis = element(app, "retour.lecturePerimee")
        XCTAssertTrue(avis.apparait(), "l'app dit pourquoi rien ne s'ouvre")
        XCTAssertFalse(app.tabBars.firstMatch.exists, "rien ne s'est ouvert")
        XCTAssertTrue(element(app, "retour.ouvrir").exists, "la session reste gardée : réessayer au retour du réseau")
    }

    @MainActor
    func testSansLectureGardeeLEchecSeDitCommeAvant() throws {
        let app = lancer("sans-lecture")
        XCTAssertTrue(element(app, "retour.ouvrir").apparait())
        let panne = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Vous êtes hors ligne")).firstMatch
        XCTAssertTrue(panne.apparait(), "la phrase de la panne")
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        XCTAssertFalse(element(app, "retour.lecturePerimee").exists)
    }
}
