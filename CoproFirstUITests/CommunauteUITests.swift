// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Communauté, FAQ, Profil et Notifications (#14), contre l'API simulée. Captures et
/// rendus : `LancementCaptures`.
final class CommunauteUITests: XCTestCase {

    @MainActor private func lancer() -> XCUIApplication { LancementCaptures.lancer() }

    @MainActor private func capture(_ nom: String) { LancementCaptures.capturer(nom) }

    /// Un élément de cet identifiant dit-il `texte` (libellé ou valeur) ? `sonde` : pour
    /// prouver qu'il ne le dit PAS, sans attendre le plafond.
    /// Par prédicat sur TOUS les éléments de l'identifiant : sous iOS 26.5, un bouton de
    /// barre d'outils est enveloppé dans un conteneur de même identifiant, que
    /// `firstMatch` rendrait — sans le libellé ni la valeur du bouton.
    private func lu(_ app: XCUIApplication, _ identifiant: String, contient texte: String, sonde: Bool = false)
        -> Bool {
        let predicat = NSPredicate(
            format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)", identifiant, texte, texte)
        let element = app.descendants(matching: .any).matching(predicat).firstMatch
        return sonde ? element.sonde() : element.apparait()
    }

    /// Un élément de cet identifiant est-il inactif ? (Le conteneur, lui, l'est toujours.)
    private func inactif(_ app: XCUIApplication, _ identifiant: String) -> Bool {
        let predicat = NSPredicate(format: "identifier == %@ AND isEnabled == false", identifiant)
        return app.descendants(matching: .any).matching(predicat).firstMatch.apparait()
    }

    /// Un élément par son identifiant (ou son libellé), QUEL QUE SOIT SON TYPE : un `Link`
    /// n'a pas le même type d'accessibilité sous iOS 26 (CI) et 27 (poste).
    private func el(_ app: XCUIApplication, _ identifiant: String) -> XCUIElement {
        app.descendants(matching: .any)[identifiant].firstMatch
    }

    /// Le premier élément dont le libellé contient `texte`, quel que soit son type.
    private func texte(_ app: XCUIApplication, _ texte: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", texte)).firstMatch
    }

    /// L'élément, ramené à l'écran : en très grand texte, il faut souvent défiler.
    @discardableResult
    private func atteindre(_ app: XCUIApplication, _ element: XCUIElement) -> XCUIElement {
        _ = element.apparait()
        var essais = 0
        while !(element.exists && element.isHittable), essais < 8 {
            app.swipeUp()
            essais += 1
        }
        return element
    }

    /// Une rubrique de la Communauté : la barre défile jusqu'à elle (très grand texte).
    private func rubrique(_ app: XCUIApplication, _ id: String) {
        let onglet = el(app, "communaute.onglet.\(id)")
        XCTAssertTrue(onglet.apparait())
        var essais = 0
        // Hors de l'écran, l'élément n'a pas de point d'activation : on compare les cadres.
        let ecran = app.windows.firstMatch.frame
        while !ecran.contains(onglet.frame), essais < 4 {
            // Un glissé du doigt sur la barre, de droite à gauche, à sa hauteur.
            let origine = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            let depart = origine.withOffset(CGVector(dx: ecran.width * 0.85, dy: onglet.frame.midY))
            depart.press(forDuration: 0.05, thenDragTo: origine.withOffset(
                CGVector(dx: ecran.width * 0.15, dy: onglet.frame.midY)))
            essais += 1
        }
        onglet.tap()
    }

    /// La partie d'un élément qui se voit, entre les barres du haut et du bas (une
    /// marge de 140 pt chacune) ; `nil` s'il n'en montre pas assez pour un doigt.
    private func visible(_ app: XCUIApplication, _ element: XCUIElement) -> CGRect? {
        guard element.exists else { return nil }
        let fenetre = app.windows.firstMatch.frame
        let zone = fenetre.insetBy(dx: 0, dy: 140)
        let partie = element.frame.intersection(zone)
        return partie.height >= 44 ? partie : nil
    }

    /// Toucher au milieu de ce qui se voit : une ligne en très grand texte dépasse
    /// l'écran, et son centre peut tomber sous une barre.
    private func toucherLaPartieVisible(_ app: XCUIApplication, _ element: XCUIElement) {
        guard let partie = visible(app, element) else { return XCTFail("\(element) ne se voit pas") }
        let origine = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        origine.withOffset(CGVector(dx: partie.midX, dy: partie.midY)).tap()
    }

    private func ouvrirDansPlus(_ app: XCUIApplication, _ libelle: String) {
        let plus = app.tabBars.buttons["Plus"]
        XCTAssertTrue(plus.apparait())
        plus.tap()
        let ligne = atteindre(app, el(app, libelle))
        XCTAssertTrue(ligne.exists, "« \(libelle) » dans Plus")
        ligne.tap()
    }

    @MainActor
    func testLaCommunauteSOuvreEtUneIdeeSeSoutient() throws {
        let app = lancer()
        ouvrirDansPlus(app, "Communauté")
        XCTAssertTrue(el(app, "sondage.12").apparait())
        capture("1-communaute-sondages")

        rubrique(app, "idees")
        let coeur = atteindre(app, el(app, "idee.5.voter"))
        XCTAssertTrue(coeur.exists)
        XCTAssertEqual(coeur.label, "Voter pour cette idée")
        coeur.tap()
        XCTAssertTrue(
            lu(app, "idee.5.voter", contient: "Retirer mon vote"), "le cœur se remplit, le vote se voit")
        capture("2-communaute-idees")

        atteindre(app, el(app, "idee.3")).tap()
        XCTAssertTrue(atteindre(app, texte(app, "Excellente idée, je veux bien m'en occuper.")).exists)
        capture("3-idee-et-reponses")
        app.navigationBars.buttons.firstMatch.tap()

        rubrique(app, "annonces")
        let annonce = atteindre(app, el(app, "annonce.21"))
        XCTAssertTrue(annonce.exists)
        capture("4-communaute-annonces")
        annonce.tap()
        XCTAssertTrue(atteindre(app, el(app, "annonce.contact")).exists, "le contact est un lien")
        capture("5-annonce")
        app.navigationBars.buttons.firstMatch.tap()

        rubrique(app, "avis")
        XCTAssertTrue(app.descendants(matching: .any)["avis.4"].apparait())
        capture("6-communaute-avis")
        el(app, "communaute.creer").tap()
        XCTAssertTrue(app.navigationBars["Donner mon avis"].apparait())
        XCTAssertTrue(inactif(app, "formulaire.enregistrer"), "rien n'est saisi : le bouton attend")
        capture("7-donner-mon-avis")
    }

    /// La cloche du Fil : « Tout marquer lu » et « Modifier » doivent SE VOIR, en haut —
    /// un bouton présent mais caché (sous la barre d'onglets) ne compte pas (`isHittable`).
    @MainActor
    func testLaClocheOuvreLesNotificationsEtToutSeMarqueLu() throws {
        let app = lancer()
        let cloche = el(app, "cloche")
        XCTAssertTrue(cloche.apparait())
        // VoiceOver lit le nombre : dans la valeur, ou dans la pastille que la barre d'iOS 26 y ajoute.
        XCTAssertTrue(
            lu(app, "cloche", contient: "12"),
            "la cloche dit 12 non lues — lu : \(cloche.label) / \(cloche.value ?? "")")
        Thread.sleep(forTimeInterval: 3)  // la pastille de la barre apparaît en fondu
        capture("7b-cloche")
        cloche.tap()
        let tout = el(app, "notifications.toutMarquerLu")
        XCTAssertTrue(tout.apparait())
        XCTAssertTrue(tout.isHittable, "« Tout marquer lu » se voit et se touche, en haut")
        XCTAssertTrue(el(app, "notifications.modifier").isHittable, "« Modifier » se voit et se touche, en haut")
        capture("8-notifications")
        tout.tap()
        XCTAssertTrue(tout.disparait(), "plus rien à marquer")
        el(app, "notifications.ok").tap()
        XCTAssertFalse(lu(app, "cloche", contient: "12", sonde: true), "la cloche n'a plus de pastille")
    }

    /// La cloche d'un menu de « Plus » : « Modifier », trois alertes choisies, supprimées
    /// après confirmation — une requête par alerte.
    @MainActor
    func testPlusieursNotificationsSeSuppriment() throws {
        let app = lancer()
        ouvrirDansPlus(app, "Communauté")
        XCTAssertTrue(el(app, "sondage.12").apparait())
        el(app, "cloche").tap()
        let modifier = el(app, "notifications.modifier")
        XCTAssertTrue(modifier.apparait())
        XCTAssertTrue(modifier.isHittable, "« Modifier » se voit et se touche, en haut")
        modifier.tap()
        for id in [5, 4, 3] {
            // Un cran à la fois : en très grand texte, une ligne vaut un écran, et un
            // balayage rapide sortirait la voisine de la liste.
            let ligne = el(app, "notification.\(id)")
            var crans = 0
            while visible(app, ligne) == nil, crans < 6 {
                app.swipeUp(velocity: .slow)
                crans += 1
            }
            toucherLaPartieVisible(app, ligne)
        }
        let supprimer = el(app, "notifications.supprimerSelection")
        XCTAssertTrue(supprimer.apparait())
        XCTAssertTrue(supprimer.isHittable, "la suppression se voit, au bas de la liste")
        XCTAssertTrue(lu(app, "notifications.supprimerSelection", contient: "(3)"), "trois alertes choisies")
        capture("8b-notifications-modifier")
        supprimer.tap()
        let confirmer = el(app, "notifications.confirmerSuppression")
        XCTAssertTrue(confirmer.apparait(), "la suppression se confirme : elle est définitive")
        confirmer.tap()
        XCTAssertTrue(el(app, "notification.5").disparait(), "les trois alertes sont parties")
        XCTAssertFalse(el(app, "notification.4").exists)
        XCTAssertFalse(el(app, "notification.3").exists)
        // Deux non lues parties (5 et 4) : 12 → 10 ; et la voisine reste (au-dessus,
        // après la suppression, en très grand texte).
        XCTAssertTrue(texte(app, "10 non lues").apparait(), "le compte suit")
        let restante = el(app, "notification.2")
        var crans = 0
        while !restante.exists, crans < 6 {
            app.swipeDown(velocity: .slow)
            crans += 1
        }
        XCTAssertTrue(restante.exists, "les autres restent")
    }

    /// « Supprimer les lues » (#53) : le geste du site, direct — sans « Modifier » ni
    /// sélection —, confirmé, puis absent dès qu'il n'y a plus de notification lue.
    @MainActor
    func testLesLuesSeSupprimentDUnGeste() throws {
        let app = lancer()
        XCTAssertTrue(el(app, "cloche").apparait())
        el(app, "cloche").tap()
        let lues = el(app, "notifications.supprimerLues")
        XCTAssertTrue(lues.apparait(), "le geste se voit dès l'ouverture, en tête de la liste")
        XCTAssertTrue(lues.isHittable, "et se touche, sans passer par « Modifier »")
        XCTAssertGreaterThanOrEqual(lues.frame.height, 44, "une cible tactile entière")
        capture("8c-notifications-supprimer-les-lues")
        lues.tap()
        let confirmer = el(app, "notifications.confirmerSuppression")
        XCTAssertTrue(confirmer.apparait(), "la suppression se confirme : elle est définitive")
        XCTAssertTrue(texte(app, "Les 138 notifications lues").exists, "la confirmation dit ce qui part")
        capture("8d-notifications-confirmer-les-lues")
        confirmer.tap()
        XCTAssertTrue(el(app, "notification.3").disparait(), "les lues sont parties")
        XCTAssertTrue(texte(app, "Notifications lues supprimées").apparait(), "et l'app le dit")
        capture("8e-notifications-lues-supprimees")
        XCTAssertTrue(el(app, "notification.5").exists, "les non lues restent")
        XCTAssertTrue(lues.disparait(), "plus aucune lue : le geste n'est plus offert")
    }

    /// « Modifier », « Tout sélectionner », « Supprimer (n) », confirmé — dans une cloche de
    /// 520 alertes, plus qu'UNE requête n'en supprime (la borne du contrat, que l'API
    /// simulée applique comme le serveur ; `NotificationsTests` la lit du contrat).
    @MainActor
    private func supprimerToutesLesNotifications(
        _ app: XCUIApplication, nombre: String? = nil, capture nom: String? = nil
    ) {
        let modifier = el(app, "notifications.modifier")
        XCTAssertTrue(modifier.apparait())
        modifier.tap()
        let toutes = el(app, "notifications.toutSelectionner")
        XCTAssertTrue(toutes.apparait())
        toutes.tap()
        let supprimer = el(app, "notifications.supprimerSelection")
        XCTAssertTrue(supprimer.apparait())
        if let nombre {
            XCTAssertTrue(lu(app, "notifications.supprimerSelection", contient: "(\(nombre))"), "toutes sont choisies")
        }
        if let nom { capture(nom) }
        supprimer.tap()
        let confirmer = el(app, "notifications.confirmerSuppression")
        XCTAssertTrue(confirmer.apparait(), "la suppression se confirme : elle est définitive")
        confirmer.tap()
    }

    /// Plus de notifications choisies qu'une requête n'en accepte (#118) : tout part, sans
    /// erreur — le serveur répondait 422, et l'écran une phrase générique.
    @MainActor
    func testUneGrandeSelectionSeSupprimeEntiere() throws {
        let app = LancementCaptures.lancer(arguments: ["-notifications", "520"])
        XCTAssertTrue(el(app, "cloche").apparait())
        el(app, "cloche").tap()
        supprimerToutesLesNotifications(app, nombre: "520", capture: "8f-notifications-grande-selection")
        XCTAssertTrue(texte(app, "Aucune notification").apparait(), "les 520 sont parties")
        XCTAssertFalse(el(app, "notifications.echec").exists, "et aucune erreur ne s'affiche")
        capture("8g-notifications-grande-selection-supprimee")
    }

    /// Le réseau tombe à la deuxième requête (#118) : ce qui est supprimé a disparu, le
    /// reste demeure, la phrase dit combien — et le second essai finit le travail.
    @MainActor
    func testUneGrandeSuppressionInterrompueLeDit() throws {
        let app = LancementCaptures.lancer(arguments: ["-notifications", "520", "-panne-suppression", "2"])
        XCTAssertTrue(el(app, "cloche").apparait())
        el(app, "cloche").tap()
        supprimerToutesLesNotifications(app, nombre: "520")
        XCTAssertTrue(
            lu(app, "notifications.echec", contient: "sur 520 ont été supprimées"),
            "la phrase dit ce qui est parti")
        XCTAssertTrue(lu(app, "notifications.echec", contient: "sont toujours là"), "et ce qui reste")
        XCTAssertTrue(lu(app, "notifications.echec", contient: "hors ligne"), "puis pourquoi")
        XCTAssertTrue(el(app, "notifications.modifier").exists, "le reste demeure dans la liste")
        XCTAssertFalse(el(app, "notification.5").exists, "ce qui est supprimé a disparu")
        capture("8h-notifications-suppression-interrompue")

        supprimerToutesLesNotifications(app)
        XCTAssertTrue(texte(app, "Aucune notification").apparait(), "le second essai finit")
        XCTAssertFalse(el(app, "notifications.echec").exists, "et la phrase s'efface")
    }

    @MainActor
    func testLaFAQEtLeProfilSOuvrent() throws {
        let app = lancer()
        ouvrirDansPlus(app, "FAQ")
        let question = atteindre(app, app.descendants(matching: .any)["faq.2"])
        XCTAssertTrue(question.exists)
        question.tap()
        let reponse = texte(app, "Pas de gravats")
        XCTAssertTrue(atteindre(app, reponse).exists, "la réponse s'est dépliée")
        capture("9-faq")
        app.navigationBars.buttons.firstMatch.tap()

        atteindre(app, el(app, "plus.profil")).tap()
        XCTAssertTrue(atteindre(app, texte(app, "resident@exemple.fr")).exists)
        capture("10-profil")
        let sombre = atteindre(app, el(app, "profil.theme").buttons["Sombre"])
        XCTAssertTrue(sombre.exists)
        sombre.tap()
        XCTAssertTrue(sombre.isSelected, "le thème choisi est retenu")
        capture("11-profil-theme-sombre")
    }
}
