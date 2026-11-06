// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import UIKit
import XCTest

/// #33 — en très grand texte (AX5), sur CHAQUE écran de menu (les onglets de la barre,
/// puis chaque entrée de « Plus », l'espace CS compris quand le compte y a droit) :
/// le titre reste en ligne et se lit en entier, et aucun libellé de « Plus » ne se
/// coupe au milieu d'un mot. Toujours lancé en AX5 : c'est le garde-fou.
/// `TEST_RUNNER_CAPTURES=<dossier>` y laisse une capture par écran ; `TEST_RUNNER_THEME`
/// en change le thème (`LancementCaptures`).
final class GrandTexteUITests: XCTestCase {
    private let ax5 = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
    /// Le bord gauche du premier libellé de « Plus » : les suivants s'y alignent.
    private var colonne: CGFloat?

    @MainActor
    func testEnAX5ChaqueTitreSeLitEtPlusNeCoupeAucunMot() throws {
        let app = LancementCaptures.lancer(taille: .ax5)
        parcourir(app, ecran: { verifierTitre(app, ecran: $0) }, entree: verifierLibelleEntier)
    }

    /// Les mêmes écrans à la taille par défaut, pour montrer que rien n'y a bougé :
    /// des captures seulement, quand un dossier est demandé.
    @MainActor
    func testCapturesALaTailleParDefaut() throws {
        guard ProcessInfo.processInfo.environment["CAPTURES"] != nil else {
            throw XCTSkip("captures seulement (TEST_RUNNER_CAPTURES)")
        }
        let app = LancementCaptures.lancer(taille: .parDefaut)
        parcourir(
            app,
            ecran: { ecran in
                XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
                LancementCaptures.capturer(ecran + "-defaut")
            }, entree: { _ in })
    }

    /// Chaque onglet, puis chaque entrée de « Plus » (le dernier onglet) : `entree` sur
    /// l'entrée dans la liste, `ecran` une fois l'écran ouvert.
    @MainActor
    private func parcourir(_ app: XCUIApplication, ecran: (String) -> Void, entree: (XCUIElement) -> Void) {
        let barre = app.tabBars.firstMatch
        XCTAssertTrue(barre.waitForExistence(timeout: 5))
        let onglets = barre.buttons.count
        XCTAssertGreaterThan(onglets, 1)
        for rang in 0..<onglets {
            barre.buttons.element(boundBy: rang).tap()
            ecran(rang == onglets - 1 ? "plus" : "onglet-\(rang + 1)")
        }
        let identifiants = entreesDePlus(app)
        XCTAssertTrue(identifiants.contains("plus.profil"), "toute la liste « Plus », jusqu'au Profil")
        for identifiant in identifiants {
            let ligne = app.buttons[identifiant]
            ligne.defilerJusquA(app)
            entree(ligne)
            ligne.tap()
            ecran(identifiant)
            barre.buttons.element(boundBy: onglets - 1).tap()  // revient à la racine de « Plus »
            XCTAssertTrue(app.buttons[identifiant].waitForExistence(timeout: 5))
        }
    }

    /// Les identifiants des entrées de « Plus », dans l'ordre. En AX5 la liste dépasse
    /// l'écran, et une cellule hors de l'écran n'existe pas encore : on la fait défiler.
    @MainActor
    private func entreesDePlus(_ app: XCUIApplication) -> [String] {
        let entrees = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'plus.'"))
        XCTAssertTrue(entrees.firstMatch.waitForExistence(timeout: 5), "la liste « Plus » est là")
        var vus: [String] = []
        for _ in 0..<8 {
            let nouveaux = entrees.allElementsBoundByIndex.map(\.identifier).filter { !vus.contains($0) }
            if nouveaux.isEmpty, !vus.isEmpty { break }
            vus += nouveaux
            app.swipeUp()
        }
        return vus
    }

    /// Le titre de l'écran : dans la barre, en ligne (pas un grand titre), et entier —
    /// sa largeur affichée est sa largeur naturelle à la police plafonnée des barres, à
    /// quelques pour cent près (le crénage de la barre : ~96 %). Un titre tronqué en
    /// perd bien plus (« Mes lots… » : 57 %).
    @MainActor
    private func verifierTitre(_ app: XCUIApplication, ecran: String) {
        let barre = app.navigationBars.firstMatch
        XCTAssertTrue(barre.waitForExistence(timeout: 5), "\(ecran) : une barre de navigation")
        let texte = barre.identifier
        let titre = barre.staticTexts[texte]
        LancementCaptures.capturer(ecran + "-ax5")
        guard titre.waitForExistence(timeout: 3) else {
            return XCTFail("\(ecran) : le titre « \(texte) » n'est pas dans la barre (chassé par ses boutons)")
        }
        let police = UIFont.preferredFont(forTextStyle: .headline, compatibleWith: plafondDesBarres)
        XCTAssertLessThanOrEqual(
            titre.frame.height, police.lineHeight * 1.5,
            "\(ecran) : « \(texte) » est un titre en ligne, pas un grand titre")
        let naturelle = (texte as NSString).size(withAttributes: [.font: serif(police)]).width
        XCTAssertGreaterThanOrEqual(
            titre.frame.width, naturelle * 0.9, "\(ecran) : « \(texte) » se lit en entier, sans « … »")
    }

    /// Un libellé de « Plus » ne prend pas plus de lignes qu'il n'a de mots — un mot
    /// coupé en syllabes (« An-nuaire ») en prendrait une de plus — et ne déborde pas
    /// de son entrée : un mot trop large pour elle, ni coupé ni rapetissé, la recentre
    /// et la décale de la colonne des autres libellés.
    @MainActor
    private func verifierLibelleEntier(_ entree: XCUIElement) {
        let libelle = entree.label
        let mots = libelle.split(separator: " ").count
        // Le texte seul : la plus basse des zones de texte de l'entrée (l'autre réunit
        // le pictogramme et le libellé, pour VoiceOver).
        guard let texte = entree.staticTexts.allElementsBoundByIndex.min(by: { $0.frame.height < $1.frame.height })
        else { return XCTFail("« \(libelle) » : aucun texte dans l'entrée") }
        let ligne = UIFont.preferredFont(forTextStyle: .body, compatibleWith: ax5).lineHeight
        let lignes = Int((texte.frame.height / ligne).rounded())
        XCTAssertGreaterThan(lignes, 0, "« \(libelle) » : un texte mesurable")
        XCTAssertLessThanOrEqual(
            lignes, mots, "« \(libelle) » : \(lignes) ligne(s) pour \(mots) mot(s) — un mot est coupé")
        let bord = texte.frame.minX
        if let colonne {
            XCTAssertEqual(bord, colonne, accuracy: 1, "« \(libelle) » déborde de son entrée : décalé de la colonne")
        } else {
            colonne = bord
        }
    }

    /// Les barres ne grossissent plus au-delà de la plus grande taille ordinaire
    /// (`ApparenceNavigation.tailleMaximale`).
    private var plafondDesBarres: UITraitCollection {
        UITraitCollection(preferredContentSizeCategory: .extraExtraExtraLarge)
    }

    private func serif(_ police: UIFont) -> UIFont {
        let graisse: [UIFontDescriptor.TraitKey: Any] = [.weight: UIFont.Weight.semibold]
        let gras = police.fontDescriptor.addingAttributes([.traits: graisse])
        return UIFont(descriptor: gras.withDesign(.serif) ?? gras, size: police.pointSize)
    }

}

extension XCUIElement {
    /// Fait défiler l'écran jusqu'à rendre l'élément touchable : la liste est longue en
    /// AX5, et une cellule sortie de l'écran n'existe plus. Vers le bas, puis vers le haut.
    @MainActor
    fileprivate func defilerJusquA(_ app: XCUIApplication) {
        for versLeBas in [true, false] {
            for _ in 0..<8 where !(exists && isHittable) {
                if versLeBas { app.swipeUp() } else { app.swipeDown() }
            }
        }
    }
}
