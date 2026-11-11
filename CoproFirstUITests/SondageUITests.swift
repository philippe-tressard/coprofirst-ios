// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// La fiche d'un sondage comme celle du site (#38), contre l'API simulée : la réponse à
/// préciser, le commentaire, la charte, le vote, les résultats et le fil des commentaires.
/// Éléments par identifiant (`elementAcces`), jamais par type ; chaque élément qui peut
/// être hors de l'écran est ramené avant d'être touché (leçon de #64).
final class SondageUITests: XCTestCase {

    @MainActor
    private func ouvrirLeSondage() -> XCUIApplication {
        let app = LancementCaptures.lancer()
        // Le fil se charge, puis la carte peut être sous l'écran (très grand texte).
        XCTAssertTrue(app.elementAcces("fil.ticket_ouvert:41").waitForExistence(timeout: 8), "le fil est chargé")
        toucher(app.elementAcces("fil.sondage_ouvert:3"), dans: app)
        XCTAssertTrue(app.elementAcces("sondage.question").waitForExistence(timeout: 8))
        return app
    }

    /// Le libellé ou la valeur d'un élément de cet identifiant contient-il `texte` ? Par
    /// prédicat sur TOUS les éléments de l'identifiant : un conteneur peut le porter aussi.
    @MainActor
    private func dit(_ app: XCUIApplication, _ identifiant: String, _ texte: String, delai: TimeInterval = 8) -> Bool {
        let predicat = NSPredicate(
            format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)", identifiant, texte, texte)
        return app.descendants(matching: .any).matching(predicat).firstMatch.waitForExistence(timeout: delai)
    }

    /// `dit`, après avoir ramené l'élément à l'écran : une liste ne garde que ses rangées visibles.
    @MainActor
    private func vu(_ app: XCUIApplication, _ identifiant: String, _ texte: String) -> Bool {
        ramener(app.elementAcces(identifiant), dans: app)
        return dit(app, identifiant, texte)
    }

    @MainActor
    private func inactif(_ app: XCUIApplication, _ identifiant: String) -> Bool {
        let predicat = NSPredicate(format: "identifier == %@ AND isEnabled == false", identifiant)
        return app.descendants(matching: .any).matching(predicat).firstMatch.waitForExistence(timeout: Attente.plafond)
    }

    /// Le cadre de l'élément en UNE requête d'accessibilité (`nil` s'il n'existe pas) :
    /// `exists` puis `frame` en font deux, et chacune coûte près d'une seconde ici.
    @MainActor
    private func cadre(_ element: XCUIElement) -> CGRect? { (try? element.snapshot())?.frame }

    /// La zone où un doigt touche ce qu'il voit : sous la barre de navigation (120 pt) et
    /// au-dessus de la barre d'onglets flottante (90 pt). Lue une fois par test.
    @MainActor
    private func zoneTouchable(_ app: XCUIApplication) -> CGRect {
        if let zone { return zone }
        let fenetre = app.windows.firstMatch.frame
        let lue = CGRect(x: fenetre.minX, y: fenetre.minY + 120, width: fenetre.width, height: fenetre.height - 210)
        zone = lue
        return lue
    }

    private var zone: CGRect?

    /// La partie de l'élément qui se voit dans cette zone ; `nil` s'il n'en montre pas assez
    /// pour un doigt. XCTest dit « touchable » un élément dont le centre est sous une barre.
    @MainActor
    private func partieVisible(_ element: XCUIElement, dans app: XCUIApplication) -> CGRect? {
        guard let cadre = cadre(element) else { return nil }
        let partie = cadre.intersection(zoneTouchable(app))
        // Assez pour un doigt (30 pt), ou l'élément entier s'il est plus petit (une ligne de texte).
        return partie.isNull || partie.height < min(30, cadre.height) ? nil : partie
    }

    /// L'élément ramené entre les barres (très grand texte) : une liste ne garde que ses
    /// rangées visibles. Présent, on va vers lui ; absent, on descend, puis on remonte.
    /// Rend la partie qui s'en voit.
    @MainActor @discardableResult
    private func ramener(_ element: XCUIElement, dans app: XCUIApplication) -> CGRect? {
        let milieu = zoneTouchable(app).midY
        var defile = false
        for versLeBas in [true, false] {
            for _ in 0..<14 {
                if let partie = partieVisible(element, dans: app) {
                    if defile { immobile(element) }
                    return defile ? partieVisible(element, dans: app) : partie
                }
                let auDessus = (cadre(element)?.midY ?? .infinity) < milieu
                if versLeBas && !auDessus { app.swipeUp(velocity: .slow) } else { app.swipeDown(velocity: .slow) }
                defile = true
            }
        }
        return nil
    }

    /// Ramener l'élément, puis toucher le milieu de ce qui s'en voit.
    @MainActor
    private func toucher(_ element: XCUIElement, dans app: XCUIApplication) {
        guard let partie = ramener(element, dans: app) else { return XCTFail("\(element) ne se voit pas") }
        let origine = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        origine.withOffset(CGVector(dx: partie.midX, dy: partie.midY)).tap()
    }

    /// Attendre que l'élément ne bouge plus : un toucher pendant l'inertie d'un défilement
    /// arrête la liste au lieu de toucher l'élément (le vote ne partait pas).
    @MainActor
    private func immobile(_ element: XCUIElement) {
        var avant = cadre(element)
        for _ in 0..<10 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.25))
            let apres = cadre(element)
            if apres == avant { return }
            avant = apres
        }
    }

    /// Un bouton de balayage glisse encore quand il apparaît : touché trop tôt, le doigt
    /// tombe sur la rangée, qui se referme.
    @MainActor
    private func toucherApresBalayage(_ bouton: XCUIElement) {
        XCTAssertTrue(bouton.waitForExistence(timeout: Attente.plafond), "\(bouton) après le balayage")
        immobile(bouton)
        bouton.tap()
    }

    @MainActor
    private func saisir(_ texte: String, dans identifiant: String, _ app: XCUIApplication) {
        let champ = app.elementAcces(identifiant)
        toucher(champ, dans: app)
        champ.typeText(texte)
        fermerLeClavier(app)
    }

    /// Le clavier ouvert couvre le bas de la liste, et un élément dessous reste « touchable »
    /// pour XCTest : le toucher tomberait sur une touche. « OK », au-dessus du clavier, ôte le
    /// champ actif ; sa barre part avec lui. (Le clavier logiciel peut rester dans l'arbre,
    /// hors de l'écran : c'est la barre qu'on attend.)
    @MainActor
    private func fermerLeClavier(_ app: XCUIApplication) {
        let ok = app.elementAcces("clavier.ok")
        // sonde courte : sans champ actif, la barre du clavier n'existe pas
        guard ok.waitForExistence(timeout: 2) else { return }
        ok.tap()
        XCTAssertTrue(ok.waitForNonExistence(timeout: 5), "plus aucun champ actif")
    }

    @MainActor
    func testUnVoteAPreciserCommenteSousLaCharte() throws {
        let app = ouvrirLeSondage()
        XCTAssertTrue(dit(app, "sondage.total", "29 votes"))
        LancementCaptures.capturer("1-sondage-vote")
        XCTAssertTrue(vu(app, "sondage.manque", "Sélectionnez une option"))

        toucher(app.elementAcces("sondage.option.4"), dans: app)
        XCTAssertNotNil(ramener(app.elementAcces("sondage.precision"), dans: app), "l'option demande une précision")
        XCTAssertTrue(vu(app, "sondage.manque", "Merci de préciser votre réponse dans le champ prévu"))
        XCTAssertTrue(inactif(app, "sondage.voter"))

        saisir("Le 20 juin", dans: "sondage.precision", app)
        saisir("Avec plaisir", dans: "sondage.commentaire", app)
        XCTAssertTrue(vu(app, "sondage.manque", "Vous devez accepter la charte de respect"))
        toucher(app.elementAcces("sondage.charte"), dans: app)
        XCTAssertTrue(app.elementAcces("sondage.manque").waitForNonExistence(timeout: 5), "plus rien ne manque")
        LancementCaptures.capturer("2-sondage-pret")

        toucher(app.elementAcces("sondage.voter"), dans: app)
        XCTAssertTrue(vu(app, "sondage.resultat.4", "Mon vote ✓"), "les résultats remplacent le vote")
        XCTAssertTrue(dit(app, "sondage.resultat.4", "Le 20 juin"), "ma précision rejoint les réponses libres")
        XCTAssertTrue(vu(app, "sondage.total", "30 votes"), "le vote est compté")
        LancementCaptures.capturer("3-sondage-resultats")
        XCTAssertTrue(vu(app, "reponses.entete", "Commentaires (4)"), "le commentaire du vote rejoint le fil")
    }

    @MainActor
    func testLeFilDesCommentairesSeLitSeCompleteEtSeModere() throws {
        let app = ouvrirLeSondage()
        XCTAssertTrue(vu(app, "reponses.entete", "Commentaires (3)"))
        ramener(app.elementAcces("reponse.33"), dans: app)
        LancementCaptures.capturer("4-sondage-commentaires")

        saisir("Je viendrai avec des chaises", dans: "reponses.saisie", app)
        toucher(app.elementAcces("reponses.envoyer"), dans: app)
        XCTAssertTrue(vu(app, "reponses.entete", "Commentaires (4)"), "le commentaire est publié")

        // Mon commentaire (servi `peut_supprimer`) : balayer, supprimer, confirmer.
        let mien = app.elementAcces("reponse.33")
        ramener(mien, dans: app)
        mien.swipeLeft()
        XCTAssertFalse(app.elementAcces("reponse.33.signaler").exists, "on ne signale pas son propre commentaire")
        toucherApresBalayage(app.elementAcces("reponse.33.supprimer"))
        let confirmer = app.elementAcces("reponses.confirmerSuppression")
        XCTAssertTrue(confirmer.waitForExistence(timeout: 5), "la suppression se confirme")
        confirmer.tap()
        XCTAssertTrue(app.elementAcces("reponse.33").waitForNonExistence(timeout: 8))

        // Le commentaire d'un voisin : le signaler, motif obligatoire.
        let voisin = app.elementAcces("reponse.32")
        ramener(voisin, dans: app)
        voisin.swipeLeft()
        XCTAssertFalse(app.elementAcces("reponse.32.supprimer").exists, "le serveur ne m'ouvre pas sa suppression")
        toucherApresBalayage(app.elementAcces("reponse.32.signaler"))
        // Une alerte système : ses identifiants ne descendent pas dans l'arbre d'accessibilité ;
        // on la trouve par son titre, et son champ a déjà le clavier.
        let alerte = app.elementAcces("Signaler au conseil syndical")
        XCTAssertTrue(alerte.waitForExistence(timeout: 5), "le motif est demandé")
        LancementCaptures.capturer("5-sondage-signaler")
        app.typeText("Hors sujet")
        app.alerts.firstMatch.descendants(matching: .any)["Signaler"].tap()
        XCTAssertTrue(alerte.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.elementAcces("Signalement transmis au conseil syndical").waitForExistence(timeout: 5))
    }
}
