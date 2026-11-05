// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import Testing
import UIKit

@testable import CoproFirst

/// #33 — très grand texte : les titres de barre plafonnent, les libellés de menu ne
/// coupent pas un mot.

private func taille(_ categorie: UIContentSizeCategory) -> UITraitCollection {
    UITraitCollection(preferredContentSizeCategory: categorie)
}

/// À la taille par défaut, rien ne bouge : 17 pt en ligne, 34 pt en grand titre.
@MainActor
@Test func lesTitresDeBarreGardentLeurTailleParDefaut() {
    #expect(ApparenceNavigation.serif(.headline, graisse: .semibold, traits: taille(.large)).pointSize == 17)
    #expect(ApparenceNavigation.serif(.largeTitle, graisse: .bold, traits: taille(.large)).pointSize == 34)
}

/// Aux tailles d'accessibilité, la police des barres s'arrête à la plus grande taille
/// ordinaire : au-delà, « Ma résidence » devenait « Ma ré… ».
@MainActor
@Test(arguments: [UIContentSizeCategory.accessibilityMedium, .accessibilityExtraExtraExtraLarge])
func lesTitresDeBarrePlafonnent(_ categorie: UIContentSizeCategory) {
    for (style, graisse) in [(UIFont.TextStyle.headline, UIFont.Weight.semibold), (.largeTitle, .bold)] {
        let maximale = taille(ApparenceNavigation.tailleMaximale)
        let plafond = ApparenceNavigation.serif(style, graisse: graisse, traits: maximale)
        let police = ApparenceNavigation.serif(style, graisse: graisse, traits: taille(categorie))
        #expect(police.pointSize == plafond.pointSize, "\(style.rawValue) en \(categorie.rawValue)")
        // Et le plafond est la taille du système à la plus grande taille ordinaire.
        let systeme = UIFont.preferredFont(forTextStyle: style, compatibleWith: maximale)
        #expect(plafond.pointSize == systeme.pointSize, "\(style.rawValue) : le barème du système")
    }
}

/// Les tailles essayées vont de la taille choisie à la taille par défaut, jamais en dessous.
@Test func lesTaillesEssayeesDescendentJusquALaTailleParDefaut() {
    let tailles = TexteSansCoupure.tailles(depuis: .accessibility5)
    #expect(tailles.first == .accessibility5)
    #expect(tailles.last == .large)
    #expect(tailles == tailles.sorted().reversed())
    #expect(TexteSansCoupure.tailles(depuis: .small) == [.small], "sous la taille par défaut : celle choisie, seule")
}

@Test func lePlusLongMotEstCeluiQuiDoitTenir() {
    #expect(TexteSansCoupure.plusLongMot("Mes lots & accès") == "accès")
    #expect(TexteSansCoupure.plusLongMot("Communauté") == "Communauté")
}

/// Le comportement : en AX5, « Communauté » ne tient pas sur 260 pt — le système le
/// couperait. `TexteSansCoupure` descend jusqu'à la première taille où il tient.
@Test func unMotTropLongDescendJusquAQuIlTienne() {
    let mot = "Communauté"
    #expect(TexteSansCoupure.largeurDe(mot, en: .accessibility5) > 260, "le témoin : en AX5, le mot déborde")
    let retenue = TexteSansCoupure.taille(pour: mot, dans: 260, depuis: .accessibility5)
    #expect(retenue < .accessibility5)
    #expect(TexteSansCoupure.largeurDe(mot, en: retenue) <= 260, "le mot tient, entier")
    let auDessus = TexteSansCoupure.tailles(depuis: .accessibility5).first { $0 > retenue }
    let plusGrandeQuiTienne = auDessus.map { TexteSansCoupure.largeurDe(mot, en: $0) > 260 } ?? true
    #expect(plusGrandeQuiTienne, "et c'est la plus grande qui tienne")
}

/// Ce qui tient ne bouge pas, et sans largeur connue, rien ne change.
@Test func unMotQuiTientGardeSaTaille() {
    #expect(TexteSansCoupure.taille(pour: "Annuaire", dans: 300, depuis: .large) == .large)
    #expect(TexteSansCoupure.taille(pour: "Annuaire", dans: 300, depuis: .accessibility5) == .accessibility5)
    #expect(TexteSansCoupure.taille(pour: "Communauté", dans: nil, depuis: .accessibility5) == .accessibility5)
}
