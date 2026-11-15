// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

// Propre à iOS : tvOS n'a pas de grands titres de barre. La cible Apple TV compile la
// charte SANS ce fichier (project.yml, `excludes`), jamais un `#if os(…)` ici (#218).

/// L'apparence des barres de navigation : grands titres en serif, couleur de la charte.
///
/// La police suit la taille de texte choisie jusqu'à la plus grande taille ordinaire
/// (`tailleMaximale`), puis s'arrête : comme les barres du système, un titre de barre
/// ne grossit plus aux tailles d'accessibilité — il se tronquait (« Ma ré… », #33).
/// Le titre entier reste lu par VoiceOver, et le corps de l'écran grandit, lui.
enum ApparenceNavigation {
    /// Au-delà, les titres de barre ne grossissent plus.
    static let tailleMaximale = UIContentSizeCategory.extraExtraExtraLarge

    @MainActor
    static func appliquer(_ palette: Palette) {
        let apparence = UINavigationBar.appearance()
        let couleur = UIColor(palette.text)
        apparence.largeTitleTextAttributes = [.font: serif(.largeTitle, graisse: .bold), .foregroundColor: couleur]
        apparence.titleTextAttributes = [.font: serif(.headline, graisse: .semibold), .foregroundColor: couleur]
    }

    /// Le serif d'un style, à la taille du système pour la taille de texte de `traits`
    /// (celle de l'app sinon), plafonnée à `tailleMaximale`.
    @MainActor
    static func serif(_ style: UIFont.TextStyle, graisse: UIFont.Weight, traits: UITraitCollection? = nil) -> UIFont {
        let choisie = traits?.preferredContentSizeCategory ?? UIApplication.shared.preferredContentSizeCategory
        let retenue = choisie > tailleMaximale ? tailleMaximale : choisie
        let base = UIFontDescriptor.preferredFontDescriptor(
            withTextStyle: style, compatibleWith: UITraitCollection(preferredContentSizeCategory: retenue))
        let gras = base.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: graisse]])
        return UIFont(descriptor: gras.withDesign(.serif) ?? gras, size: 0)
    }
}
