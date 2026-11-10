// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Le Paramétrage, en partie (#16), contre l'API simulée : l'administrateur y ouvre ses
/// quatre onglets et « Sur le site » ; l'opérateur, la seule Maintenance. Recherche par
/// identifiant, jamais par type ; un onglet hors de l'écran se fait défiler avant d'être
/// touché. Captures : `LancementCaptures`.
final class AdminUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLeParametrageDeLAdministrateur() throws {
        let app = ouvrirLeParametrage(["-compte", "administrateur"])
        let aTraiter = app.elementAcces("onglet.a_traiter")
        XCTAssertTrue(aTraiter.waitForExistence(timeout: 5), "la barre d'onglets")
        for id in ["utilisateurs", "telemetry", "maintenance", "sur-le-site"] {
            XCTAssertTrue(app.elementAcces("onglet.\(id)").exists, "l'onglet \(id)")
        }
        XCTAssertFalse(app.elementAcces("onglet.imports").exists, "un onglet du site seul n'est pas dans la barre")

        // À traiter : la file du conseil, puis une demande de profil approuvée.
        let demande = app.elementAcces("admin.demande.41")
        for _ in 0..<8 where !demande.waitForExistence(timeout: 1) || !demande.isHittable { app.swipeUp() }
        XCTAssertTrue(demande.exists, "les demandes de profil")
        LancementCaptures.capturer("admin-1-a-traiter")
        app.elementAcces("admin.demande.41.approuver").tap()
        XCTAssertTrue(demande.waitForNonExistence(timeout: 5), "la demande quitte la file")

        lesUtilisateurs(app)
        laTelemetrie(app)
        laMaintenance(app, operateur: false)
        surLeSite(app, attendus: ["imports", "copropriete", "smtp"])
    }

    @MainActor
    func testLaMaintenanceDeLOperateur() throws {
        let app = ouvrirLeParametrage(["-compte", "operateur"])
        let maintenance = app.elementAcces("onglet.maintenance")
        XCTAssertTrue(maintenance.waitForExistence(timeout: 5), "la barre d'onglets")
        XCTAssertFalse(app.elementAcces("onglet.a_traiter").exists, "l'opérateur n'a que l'Exploitation")
        XCTAssertFalse(app.elementAcces("onglet.utilisateurs").exists)
        laMaintenance(app, operateur: true)
        surLeSite(app, attendus: ["installation", "installations"])
    }

    // MARK: - Les onglets

    @MainActor
    private func lesUtilisateurs(_ app: XCUIApplication) {
        toucherLOnglet("utilisateurs", app)
        let camille = app.elementAcces("admin.utilisateur.11")
        XCTAssertTrue(camille.waitForExistence(timeout: 5), "la liste des comptes")
        LancementCaptures.capturer("admin-2-utilisateurs")
        let recherche = app.elementAcces("admin.utilisateurs.recherche")
        recherche.tap()
        recherche.typeText("dominique")
        let dominique = app.elementAcces("admin.utilisateur.12")
        XCTAssertTrue(dominique.waitForExistence(timeout: 3))
        XCTAssertFalse(camille.exists, "la recherche filtre")
        dominique.tap()
        XCTAssertTrue(app.elementAcces("admin.fiche.fermer").waitForExistence(timeout: 3), "la fiche")
        LancementCaptures.capturer("admin-3-fiche")
        // Les gestes sont au bas du formulaire, dont les cellules naissent au défilement.
        let communaute = app.elementAcces("admin.fiche.communaute")
        let supprimer = app.elementAcces("admin.fiche.supprimer")
        for _ in 0..<6 where !supprimer.exists { app.swipeUp() }
        XCTAssertTrue(supprimer.exists, "l'administrateur peut supprimer")
        XCTAssertTrue(communaute.exists, "l'administrateur peut interdire la communauté")
        LancementCaptures.capturer("admin-3-fiche-gestes")
        communaute.tap()
        XCTAssertTrue(communaute.waitForNonExistence(timeout: 5), "le geste ferme la fiche")
    }

    @MainActor
    private func laTelemetrie(_ app: XCUIApplication) {
        toucherLOnglet("telemetry", app)
        XCTAssertTrue(app.elementAcces("admin.telemetrie.indicateurs").waitForExistence(timeout: 5), "les nombres clés")
        XCTAssertTrue(app.elementAcces("admin.telemetrie.filtre").exists, "le filtre que le serveur propose")
        LancementCaptures.capturer("admin-4-telemetrie-jour")
        app.elementAcces("admin.telemetrie.vue.annee").tap()
        XCTAssertTrue(app.elementAcces("admin.telemetrie.graphe").waitForExistence(timeout: 5), "le graphe")
        XCTAssertFalse(app.elementAcces("admin.telemetrie.filtre").exists, "rien à écarter sur douze mois")
        LancementCaptures.capturer("admin-5-telemetrie-annee")
    }

    /// L'opérateur lit la santé des tâches, l'administrateur le dernier export : chacun ce
    /// que sa route lui sert.
    @MainActor
    private func laMaintenance(_ app: XCUIApplication, operateur: Bool) {
        toucherLOnglet("maintenance", app)
        if operateur {
            XCTAssertTrue(app.elementAcces("admin.tache.backup").waitForExistence(timeout: 5), "la santé des tâches")
            XCTAssertFalse(app.elementAcces("admin.maintenance.export").exists)
            LancementCaptures.capturer("admin-6-maintenance-operateur")
        } else {
            XCTAssertTrue(app.elementAcces("admin.maintenance.export").waitForExistence(timeout: 5), "l'export")
            XCTAssertFalse(app.elementAcces("admin.tache.backup").exists, "la supervision est à l'opérateur")
            LancementCaptures.capturer("admin-6-maintenance-administrateur")
        }
    }

    @MainActor
    private func surLeSite(_ app: XCUIApplication, attendus: [String]) {
        toucherLOnglet("sur-le-site", app)
        for id in attendus {
            XCTAssertTrue(app.elementAcces("site.onglet.\(id)").waitForExistence(timeout: 3), "le lien vers \(id)")
        }
        LancementCaptures.capturer("admin-7-sur-le-site")
    }

    // MARK: - Aides

    @MainActor
    private func ouvrirLeParametrage(_ arguments: [String]) -> XCUIApplication {
        let app = LancementCaptures.lancer(arguments: arguments)
        let plus = app.descendants(matching: .any)["Plus"].firstMatch
        XCTAssertTrue(plus.waitForExistence(timeout: 8))
        plus.tap()
        let admin = app.libelleAcces("Admin")
        for _ in 0..<6 where !admin.waitForExistence(timeout: 1) || !admin.isHittable { app.swipeUp() }
        admin.tap()
        return app
    }

    /// Un onglet de la barre, défilée jusqu'à lui s'il est hors de l'écran.
    @MainActor
    private func toucherLOnglet(_ id: String, _ app: XCUIApplication) {
        let onglet = app.elementAcces("onglet.\(id)")
        for _ in 0..<6 where !onglet.isHittable { app.swipeDown() }
        // La barre défile sous le doigt : on la tire par un onglet visible.
        let barre = ["a_traiter", "utilisateurs", "telemetry", "maintenance", "sur-le-site"]
            .map { app.elementAcces("onglet.\($0)") }
        for _ in 0..<6 where !onglet.isHittable { barre.first(where: \.isHittable)?.swipeLeft() }
        onglet.tap()
    }
}
