// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// « Prestataires » (#13), sur l'API simulée : les trois onglets s'ouvrent depuis
/// « Plus », la recherche filtre, une fiche se déplie ; le conseil syndical note, corrige
/// et retire un avis (#207). Captures jointes. Recherche par identifiant ou libellé, jamais
/// par type (voir `AccesUITests`) ; chaque toucher par `app.toucher` (#217).
final class PrestatairesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Le récapitulatif servi des avis (#207) : l'exercice le plus récent ouvert, un badge
    /// d'avis qui se voit dépliable et dit, déplié, l'auteur et le commentaire.
    @MainActor
    func testLesAvisDUnPrestataireSeDeplient() throws {
        // Sombre et très grand texte selon l'environnement (`LancementCaptures`).
        let app = LancementCaptures.lancer()
        ouvrirLaFiche(app)
        XCTAssertTrue(app.elementAcces("avis.exercice.2026").apparait(), "l'exercice le plus récent")
        LancementCaptures.capturer("prestataires-2a-recapitulatif")
        app.toucher(app.elementAcces("avis.11"), essais: Self.loin)
        let detail = app.elementAcces("avis.11.detail")
        XCTAssertTrue(detail.apparait(), "l'avis déplié")
        XCTAssertTrue(detail.label.contains("délai respecté"), detail.label)
        // Pas l'auteur : pas de correction ; le conseil peut retirer (droits servis).
        XCTAssertTrue(app.elementAcces("avis.11.retirer").apparait(), "retirer : le conseil syndical")
        XCTAssertFalse(app.elementAcces("avis.11.modifier").exists, "modifier : l'auteur seul (`peut_modifier`)")
        LancementCaptures.capturer("prestataires-2b-avis")
    }

    /// Noter (#207) : rien ne part sans l'état ; une affaire où le prestataire n'intervient pas
    /// exige la confirmation de son ajout ; « Mauvais » exige un commentaire, qu'une case
    /// cochée compose. L'avis noté se lit dans le récapitulatif, et la moyenne de la carte suit.
    @MainActor
    func testNoterUnPrestataireSurUneAffaireAChoisir() throws {
        let app = LancementCaptures.lancer()
        ouvrirLaFiche(app)
        app.toucher(app.elementAcces("prestataire.1.noter"), essais: Self.loin)
        XCTAssertTrue(enregistrer(app, actif: false), "rien ne part sans l'état")
        LancementCaptures.capturer("prestataires-5a-noter")

        // La feuille est un `Form` : ses rangées n'existent qu'à l'écran — on la parcourt
        // de haut en bas.
        let recherche = app.elementAcces("avis.affaire.recherche")
        app.toucher(recherche)
        recherche.typeText("toiture")
        XCTAssertTrue(app.elementAcces("avis.affaire.52").apparait(), "les affaires à noter, filtrées")
        XCTAssertFalse(app.elementAcces("avis.affaire.45").exists, "le titre ne correspond pas")
        app.toucher(app.elementAcces("avis.affaire.52"))
        // L'affaire retenue se prouve par la case qui la nomme : au très grand texte, la
        // rangée « retenue » est déjà passée au-dessus de l'écran.
        let ajout = app.elementAcces("avis.confirmerAjout")
        XCTAssertTrue(
            app.elementDisant("avis.confirmerAjout", "« Infiltration en toiture »").apparait(),
            "il n'y intervient pas : l'ajout se confirme")
        app.toucher(ajout)
        XCTAssertTrue(ajout.isSelected)
        app.toucher(app.elementAcces("avis.etat.mauvais"))
        XCTAssertTrue(lire(app, "avis.refus", "doit être justifié"), "« Mauvais » se justifie")
        XCTAssertTrue(enregistrer(app, actif: false))
        LancementCaptures.capturer("prestataires-5b-mauvais")
        // Au très grand texte, la case est remontée hors de l'écran : on l'y ramène — la
        // feuille, déjà saisie, ne se ferme plus au glissement.
        let retard = app.elementAcces("avis.faible.0")
        XCTAssertTrue(app.amener(retard, essais: Self.loin))
        app.toucher(retard)
        XCTAssertTrue(lire(app, "avis.genere", "Points faibles : retard."), "la phrase générée")
        XCTAssertTrue(enregistrer(app, actif: true), "plus rien ne retient l'avis")
        app.toucher(app.elementAcces("avis.enregistrer"))

        XCTAssertTrue(app.libelleAcces("Notation enregistrée").apparait(), "l'avis du site")
        XCTAssertTrue(app.libelleAcces("Avis du conseil syndical (4)").apparait(), "la liste relue")
        let ligne = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ENDSWITH %@", "Infiltration en toiture")).firstMatch
        XCTAssertTrue(ligne.apparait(), "la ligne de l'affaire jugée, datée du jour")
        LancementCaptures.capturer("prestataires-5c-note")
    }

    /// Corriger son avis (`peut_modifier`) : ses cases se recochent, son texte libre revient ;
    /// puis le retirer, après la confirmation du site.
    @MainActor
    func testCorrigerPuisRetirerSonAvis() throws {
        let app = LancementCaptures.lancer()
        ouvrirLaFiche(app)
        app.toucher(app.elementAcces("avis.exercice.2025"), essais: Self.loin)
        app.toucher(app.elementAcces("avis.9"), essais: Self.loin)
        app.toucher(app.elementAcces("avis.9.modifier"), essais: Self.loin)
        XCTAssertTrue(app.navigationBars["Modifier cet avis"].apparait())
        XCTAssertTrue(app.elementAcces("avis.affaire.retenue").apparait(), "son affaire, retenue")
        let neutre = app.elementAcces("avis.etat.neutre")
        // Au très grand texte, les états sont sous le pli : on DESCEND seulement — remonter
        // une feuille intacte la fermerait.
        XCTAssertTrue(app.amener(neutre, pourLire: true))
        XCTAssertTrue(neutre.isSelected, "l'état servi")
        LancementCaptures.capturer("prestataires-6a-corriger")
        app.toucher(app.elementAcces("avis.etat.excellent"))
        let faible = app.elementAcces("avis.faible.0")
        XCTAssertTrue(app.amener(faible, pourLire: true))
        XCTAssertTrue(faible.isSelected, "la case recochée")
        XCTAssertTrue(lire(app, "avis.libre", "Réparé au second passage."), "le texte libre seul")
        app.toucher(app.elementAcces("avis.enregistrer"))
        XCTAssertTrue(app.libelleAcces("Avis modifié").apparait())
        XCTAssertTrue(app.elementDisant("avis.9", "Excellent").apparait(), "le récapitulatif relu")

        // L'avis reste déplié : ses gestes sont là.
        app.toucher(app.elementAcces("avis.9.retirer"), essais: Self.loin)
        let confirmer = app.elementAcces("avis.confirmerRetrait")
        XCTAssertTrue(confirmer.apparait(), "le retrait se confirme")
        LancementCaptures.capturer("prestataires-6b-retirer")
        app.toucher(confirmer)
        XCTAssertTrue(app.libelleAcces("Avis retiré.").apparait())
        XCTAssertTrue(app.elementAcces("avis.9").disparait(), "l'avis n'est plus")
        XCTAssertTrue(app.libelleAcces("Avis du conseil syndical (2)").apparait(), "la liste relue")
    }

    /// Au très grand texte, la fiche dépliée fait quatre écrans : assez de glissements.
    private static let loin = 30

    @MainActor
    private func ouvrirLaFiche(_ app: XCUIApplication) {
        app.ouvrirDansPlus("Prestataires", jusqua: app.elementAcces("prestataire.1"))
        let fiche = app.elementAcces("prestataire.1")
        XCTAssertTrue(fiche.apparait())
        app.toucher(fiche)
    }

    /// Une rangée de la feuille qui dit `texte`, amenée à l'écran pour exister.
    private func lire(_ app: XCUIApplication, _ identifiant: String, _ texte: String) -> Bool {
        let element = app.elementDisant(identifiant, texte)
        return element.sonde() || app.amener(element, essais: Self.loin, pourLire: true)
    }

    /// « Enregistrer » actif ou grisé. Le grisé se lit sur tous les éléments de l'identifiant :
    /// son conteneur, lui, est toujours actif (#11) — actif, c'est donc qu'aucun n'est grisé.
    private func enregistrer(_ app: XCUIApplication, actif: Bool) -> Bool {
        let grise = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND isEnabled == false", "avis.enregistrer")).firstMatch
        return actif ? grise.disparait() : grise.apparait()
    }

    @MainActor
    func testLesTroisOngletsSOuvrent() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-api-simulee", "-ecran", "fil"]
        app.launch()
        app.ouvrirDansPlus("Prestataires", jusqua: app.navigationBars["Prestataires"])
        XCTAssertTrue(app.navigationBars["Prestataires"].apparait())

        let fiche = app.elementAcces("prestataire.1")
        XCTAssertTrue(fiche.apparait(), "les fiches")
        app.capturerAcces("prestataires-1-liste", dans: self)
        app.toucher(fiche)
        XCTAssertTrue(app.libelleAcces("Avis du conseil syndical (3)").apparait(), "la fiche dépliée")
        app.capturerAcces("prestataires-2-fiche", dans: self)

        let recherche = app.elementAcces("prestataires.recherche")
        app.toucher(recherche)
        recherche.typeText("incendie controles")
        XCTAssertTrue(app.elementAcces("prestataire.2").apparait())
        XCTAssertFalse(app.elementAcces("prestataire.1").exists, "la recherche filtre, sans accents ni ordre")
        recherche.typeText(XCUIKeyboardKey.delete.rawValue)

        app.toucher(app.elementAcces("onglet.contrats"))
        let contrat = app.elementAcces("contrat.1")
        XCTAssertTrue(contrat.apparait(), "les contrats")
        // Ouvrir le contrat : un toucher perdu sous charge se reprend, déclaré (#183, #299).
        app.toucher(contrat, jusqua: app.libelleAcces("Le contrat"))
        XCTAssertTrue(app.libelleAcces("↺ Mensuel").exists, "la fréquence servie (`frequence_libelle`, #125)")
        XCTAssertTrue(app.elementAcces("contrat.1.noter").exists, "noter depuis le contrat : le conseil")
        app.capturerAcces("prestataires-3-contrats", dans: self)

        // 🔁 Le remplacement servi (#185, contrat 1.29.0), sur les deux cartes — la
        // première repliée, pour que la capture les montre.
        app.toucher(contrat)
        XCTAssertTrue(app.libelleAcces("Le contrat").disparait(), "la carte repliée")
        let remplace = app.elementAcces("contrat.2.remplacement.0")
        XCTAssertTrue(remplace.apparait(), "l'ancien contrat dit par qui il est remplacé")
        XCTAssertEqual(remplace.label, "🔁 Remplacé par Protection Incendie Exemple ·\u{00A0}dès le 01/12/2026")
        // Plus longue qu'une rangée de capsules, elle passe à la ligne au lieu de déborder
        // de la carte (capture du 13/11/2026, #191) : elle ne dépasse pas le titre du contrat.
        let titre = app.elementAcces("contrat.2")
        XCTAssertLessThanOrEqual(remplace.frame.maxX, titre.frame.maxX + 1, "la pastille tient dans la carte")
        let remplacant = app.elementAcces("contrat.4.remplacement.0")
        XCTAssertTrue(remplacant.apparait(), "le nouveau dit qui il remplace")
        XCTAssertEqual(remplacant.label, "🔁 Remplace Contrôles Sécurité Exemple (résilié au 30/11/2026)")
        XCTAssertFalse(app.elementAcces("contrat.1.remplacement.0").exists, "sans remplacement : rien")
        app.capturerAcces("prestataires-3b-remplacement", dans: self)

        app.toucher(app.elementAcces("onglet.consommations"))
        // « 47 047 » : l'espace fine insécable de `fmtNombre`.
        XCTAssertTrue(app.libelleAcces("Index 47").apparait(), "les relevés")
        app.capturerAcces("prestataires-4-consommations", dans: self)
    }
}
