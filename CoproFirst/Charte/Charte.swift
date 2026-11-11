// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

/// Une couleur en composantes 0–255, telle que la charte l'écrit.
struct RVBA: Sendable {
    let rouge: UInt8, vert: UInt8, bleu: UInt8
    let alpha: Double

    init(_ rouge: UInt8, _ vert: UInt8, _ bleu: UInt8, _ alpha: Double) {
        self.rouge = rouge
        self.vert = vert
        self.bleu = bleu
        self.alpha = alpha
    }

    var uiColor: UIColor {
        UIColor(
            red: CGFloat(rouge) / 255, green: CGFloat(vert) / 255, blue: CGFloat(bleu) / 255,
            alpha: CGFloat(alpha)
        )
    }
}

extension Color {
    /// Une couleur qui suit le thème du système : la valeur claire de `socle.css`,
    /// la sombre de `palette-sombre.css` (Palette+*.swift, générés).
    init(clair: RVBA, sombre: RVBA) {
        self.init(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? sombre.uiColor : clair.uiColor
            }
        )
    }
}

/// Typographie et mesures de l'app — écrites une fois.
///
/// Chacune est PROPRE À iOS, déclarée avec sa raison et sa date dans
/// `CoproFirstTests/MesuresTests.swift` ; une mesure dont le site a le jeton se lit dans
/// `MesuresDuSite` (généré). Une mesure ajoutée ici sans déclaration fait échouer le test (#85).
enum Mise {
    /// Rayon des cartes, des champs et des boutons (coins continus).
    static let rayon: CGFloat = 14
    /// Marge latérale des écrans.
    static let marge: CGFloat = 20
    /// Hauteur minimale d'une cible tactile (Human Interface Guidelines).
    static let cible: CGFloat = 44
    /// L'approche des libellés en capitales (`styleLibelle`).
    static let approcheLibelle: CGFloat = 0.6
}

extension Font {
    /// Un titre : le serif de la charte (New York), à la taille du style dynamique.
    static func titre(_ style: Font.TextStyle) -> Font {
        .system(style, design: .serif).weight(.semibold)
    }
}

extension View {
    /// Le libellé d'un champ ou d'une section : en capitales, comme le site.
    func styleLibelle() -> some View {
        modifier(StyleLibelle())
    }
}

private struct StyleLibelle: ViewModifier {
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.semibold))
            .tracking(Mise.approcheLibelle)
            .textCase(.uppercase)
            .foregroundStyle(palette.textMuted)
    }
}

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
