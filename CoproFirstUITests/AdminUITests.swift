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
        XCTAssertTrue(aTraiter.apparait(), "la barre d'onglets")
        for id in ["utilisateurs", "telemetry", "maintenance", "sur-le-site"] {
            XCTAssertTrue(app.elementAcces("onglet.\(id)").exists, "l'onglet \(id)")
        }
        XCTAssertFalse(app.elementAcces("onglet.imports").exists, "un onglet du site seul n'est pas dans la barre")

        // À traiter : la file du conseil, puis une demande de profil approuvée.
        let demande = app.elementAcces("admin.demande.41")
        for _ in 0..<8 where !demande.sonde() || !demande.isHittable { app.swipeUp() }
        XCTAssertTrue(demande.exists, "les demandes de profil")
        LancementCaptures.capturer("admin-1-a-traiter")
        app.elementAcces("admin.demande.41.approuver").tap()
        XCTAssertTrue(demande.disparait(), "la demande quitte la file")

        lesUtilisateurs(app)
        laTelemetrie(app)
        laMaintenance(app, operateur: false)
        surLeSite(app, attendus: ["imports", "copropriete", "smtp"])
    }

    /// #94 : sur une instance commune, la fiche du compte opérateur dit « Opérateur désigné
    /// par l'exploitant » ; sur son propre compte, la confirmation dit « votre compte ».
    @MainActor
    func testLaFicheDitLExploitantEtVotreCompte() throws {
        let app = ouvrirLeParametrage(["-compte", "administrateur", "-instance-commune"])
        app.toucherLOnglet(
            app.elementAcces("onglet.utilisateurs"), jusqua: app.elementAcces("admin.utilisateurs.recherche"))
        let parExploitant = app.elementAcces("admin.fiche.operateur-exploitant")
        ouvrirLaFiche("sacha", 15, app)
        for _ in 0..<6 where !parExploitant.sonde() { app.swipeUp() }
        XCTAssertTrue(parExploitant.exists, "le texte, à la place du geste")
        XCTAssertFalse(app.elementAcces("admin.fiche.role.operateur").exists, "aucun geste non servi")
        LancementCaptures.capturer("admin-3-fiche-operateur-exploitant")
        app.elementAcces("admin.fiche.fermer").tap()

        ouvrirLaFiche("camille", 11, app)
        let retirerCS = app.elementAcces("admin.fiche.role.conseil_syndical")
        for _ in 0..<6 where !retirerCS.sonde() { app.swipeUp() }
        app.toucher(retirerCS)
        XCTAssertTrue(
            app.libelleAcces("Retirer le rôle Conseil syndical de votre compte").apparait(),
            "la confirmation dit « votre compte »")
        LancementCaptures.capturer("admin-3-fiche-votre-compte")
    }

    @MainActor
    func testLaMaintenanceDeLOperateur() throws {
        let app = ouvrirLeParametrage(["-compte", "operateur"])
        let maintenance = app.elementAcces("onglet.maintenance")
        XCTAssertTrue(maintenance.apparait(), "la barre d'onglets")
        XCTAssertFalse(app.elementAcces("onglet.a_traiter").exists, "l'opérateur n'a que l'Exploitation")
        XCTAssertFalse(app.elementAcces("onglet.utilisateurs").exists)
        laMaintenance(app, operateur: true)
        surLeSite(app, attendus: ["installation", "installations"])
    }

    // MARK: - Les onglets

    @MainActor
    private func lesUtilisateurs(_ app: XCUIApplication) {
        app.toucherLOnglet(
            app.elementAcces("onglet.utilisateurs"), jusqua: app.elementAcces("admin.utilisateur.11"))
        let camille = app.elementAcces("admin.utilisateur.11")
        XCTAssertTrue(camille.apparait(), "la liste des comptes")
        LancementCaptures.capturer("admin-2-utilisateurs")
        let recherche = app.elementAcces("admin.utilisateurs.recherche")
        recherche.tap()
        recherche.typeText("dominique")
        let dominique = app.elementAcces("admin.utilisateur.12")
        XCTAssertTrue(dominique.apparait())
        XCTAssertFalse(camille.exists, "la recherche filtre")
        dominique.tap()
        XCTAssertTrue(app.elementAcces("admin.fiche.fermer").apparait(), "la fiche")
        LancementCaptures.capturer("admin-3-fiche")
        // Les gestes sont au bas du formulaire, dont les cellules naissent au défilement.
        let communaute = app.elementAcces("admin.fiche.communaute")
        let supprimer = app.elementAcces("admin.fiche.supprimer")
        for _ in 0..<6 where !supprimer.exists { app.swipeUp() }
        XCTAssertTrue(supprimer.exists, "l'administrateur peut supprimer")
        XCTAssertTrue(communaute.exists, "l'administrateur peut interdire la communauté")
        LancementCaptures.capturer("admin-3-fiche-gestes")
        communaute.tap()
        XCTAssertTrue(communaute.disparait(), "le geste ferme la fiche")
        lesGestesDeRole(app)
    }

    /// Les gestes de rôle que le serveur sert (#89) : Alix, copropriétaire, peut recevoir
    /// le conseil syndical ; le geste confirmé ferme la fiche.
    @MainActor
    private func lesGestesDeRole(_ app: XCUIApplication) {
        let recherche = app.elementAcces("admin.utilisateurs.recherche")
        recherche.tap()
        recherche.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "alix")
        let alix = app.elementAcces("admin.utilisateur.13")
        XCTAssertTrue(alix.apparait())
        alix.tap()
        let ajouterCS = app.elementAcces("admin.fiche.role.conseil_syndical")
        for _ in 0..<6 where !ajouterCS.exists { app.swipeUp() }
        XCTAssertTrue(ajouterCS.exists, "« + CS », servi par le serveur")
        XCTAssertFalse(app.elementAcces("admin.fiche.role.operateur").exists, "aucun geste non servi")
        LancementCaptures.capturer("admin-3-fiche-roles")
        app.toucher(ajouterCS)
        let confirmer = app.buttons["Confirmer"].firstMatch
        XCTAssertTrue(confirmer.apparait(), "la confirmation du geste")
        app.toucher(confirmer)
        XCTAssertTrue(ajouterCS.disparait(), "le geste ferme la fiche")
    }

    @MainActor
    private func laTelemetrie(_ app: XCUIApplication) {
        app.toucherLOnglet(
            app.elementAcces("onglet.telemetry"), jusqua: app.elementAcces("admin.telemetrie.indicateurs"))
        XCTAssertTrue(app.elementAcces("admin.telemetrie.indicateurs").apparait(), "les nombres clés")
        XCTAssertTrue(app.elementAcces("admin.telemetrie.filtre").exists, "le filtre que le serveur propose")
        LancementCaptures.capturer("admin-4-telemetrie-jour")
        app.elementAcces("admin.telemetrie.vue.annee").tap()
        XCTAssertTrue(app.elementAcces("admin.telemetrie.graphe").apparait(), "le graphe")
        XCTAssertFalse(app.elementAcces("admin.telemetrie.filtre").exists, "rien à écarter sur douze mois")
        LancementCaptures.capturer("admin-5-telemetrie-annee")
        // L'accès, site ou application, servi au-dessus du plancher (coprofirst#2726), sous le graphe.
        let accesApp = app.elementAcces("admin.telemetrie.acces.ios")
        for _ in 0..<6 where !accesApp.exists { app.swipeUp() }
        XCTAssertTrue(accesApp.exists, "les vues de l'app, servies")
    }

    /// L'opérateur lit la santé des tâches, l'administrateur le dernier export : chacun ce
    /// que sa route lui sert.
    @MainActor
    private func laMaintenance(_ app: XCUIApplication, operateur: Bool) {
        let effet = app.elementAcces(operateur ? "admin.tache.backup" : "admin.maintenance.export")
        app.toucherLOnglet(app.elementAcces("onglet.maintenance"), jusqua: effet)
        if operateur {
            XCTAssertTrue(app.elementAcces("admin.tache.backup").apparait(), "la santé des tâches")
            XCTAssertFalse(app.elementAcces("admin.maintenance.export").exists)
            LancementCaptures.capturer("admin-6-maintenance-operateur")
        } else {
            XCTAssertTrue(app.elementAcces("admin.maintenance.export").apparait(), "l'export")
            XCTAssertFalse(app.elementAcces("admin.tache.backup").exists, "la supervision est à l'opérateur")
            LancementCaptures.capturer("admin-6-maintenance-administrateur")
        }
    }

    @MainActor
    private func surLeSite(_ app: XCUIApplication, attendus: [String]) {
        app.toucherLOnglet(
            app.elementAcces("onglet.sur-le-site"), jusqua: app.elementAcces("site.onglet.\(attendus[0])"))
        for id in attendus {
            XCTAssertTrue(app.elementAcces("site.onglet.\(id)").apparait(), "le lien vers \(id)")
        }
        LancementCaptures.capturer("admin-7-sur-le-site")
    }

    // MARK: - Aides

    /// La fiche du compte `id`, trouvée par la recherche.
    @MainActor
    private func ouvrirLaFiche(_ recherche: String, _ id: Int, _ app: XCUIApplication) {
        let champ = app.elementAcces("admin.utilisateurs.recherche")
        XCTAssertTrue(champ.apparait(), "la liste des comptes")
        champ.tap()
        champ.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + recherche)
        let ligne = app.elementAcces("admin.utilisateur.\(id)")
        XCTAssertTrue(ligne.apparait())
        ligne.tap()
        XCTAssertTrue(app.elementAcces("admin.fiche.fermer").apparait(), "la fiche")
    }

    @MainActor
    private func ouvrirLeParametrage(_ arguments: [String]) -> XCUIApplication {
        let app = LancementCaptures.lancer(arguments: arguments)
        let plus = app.descendants(matching: .any)["Plus"].firstMatch
        XCTAssertTrue(plus.apparait())
        plus.tap()
        let admin = app.libelleAcces("Admin")
        for _ in 0..<6 where !admin.sonde() || !admin.isHittable { app.swipeUp() }
        admin.tap()
        return app
    }
}
