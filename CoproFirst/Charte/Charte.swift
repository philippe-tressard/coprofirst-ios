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
enum Mise {
    /// Rayon des cartes, des champs et des boutons (coins continus).
    static let rayon: CGFloat = 14
    /// Marge latérale des écrans.
    static let marge: CGFloat = 20
    /// Hauteur minimale d'une cible tactile (Human Interface Guidelines).
    static let cible: CGFloat = 44
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
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(palette.textMuted)
    }
}

/// L'apparence des barres de navigation : grands titres en serif, couleur de la charte.
enum ApparenceNavigation {
    @MainActor
    static func appliquer(_ palette: Palette) {
        func serif(_ style: UIFont.TextStyle, graisse: UIFont.Weight) -> UIFont {
            let base = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
            let gras = base.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: graisse]])
            let descripteur = gras.withDesign(.serif) ?? gras
            return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descripteur, size: 0))
        }
        let apparence = UINavigationBar.appearance()
        let couleur = UIColor(palette.text)
        apparence.largeTitleTextAttributes = [.font: serif(.largeTitle, graisse: .bold), .foregroundColor: couleur]
        apparence.titleTextAttributes = [.font: serif(.headline, graisse: .semibold), .foregroundColor: couleur]
    }
}
