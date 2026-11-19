// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les trois boutons de la charte : plein (l'action principale), contour, clair.
enum GenreBouton {
    case plein, contour, clair
}

struct StyleBouton: ButtonStyle {

    @Environment(\.palette) private var palette
    let genre: GenreBouton
    @Environment(\.isEnabled) private var actif

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 16)
            .foregroundStyle(premierPlan)
            .background(fond, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
            .overlay {
                if genre == .contour {
                    RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                        .strokeBorder(palette.primary, lineWidth: 1.5)
                }
            }
            .opacity(actif ? 1 : 0.45)
            .appuiCharte(configuration.isPressed)
            .contentShape(.rect(cornerRadius: Mise.rayon))
            .survolCharte()
    }

    private var premierPlan: Color {
        switch genre {
        case .plein: palette.surPlein
        case .contour, .clair: palette.primary
        }
    }

    private var fond: Color {
        switch genre {
        case .plein: palette.primaryPlein
        case .contour: .clear
        case .clair: palette.primaryLight
        }
    }
}

/// Le retour au toucher de la charte : un appui se voit à l'instant (97 %), et se défait
/// aussitôt — rien quand le mouvement est réduit.
private struct AppuiCharte: ViewModifier {
    let presse: Bool
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit

    func body(content: Content) -> some View {
        content
            .scaleEffect(presse && !mouvementReduit ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: presse)
    }
}

extension View {
    func appuiCharte(_ presse: Bool) -> some View { modifier(AppuiCharte(presse: presse)) }

    /// Le survol du pointeur (iPad, trackpad ou souris, #223) : la forme entière s'éclaire,
    /// aux coins de la charte — un style de bouton propre n'en a pas d'office.
    func survolCharte() -> some View {
        contentShape(.hoverEffect, .rect(cornerRadius: Mise.rayon, style: .continuous))
            .hoverEffect(.highlight)
    }
}

/// Un bouton dont le libellé porte déjà sa forme : seul l'appui de la charte s'y ajoute.
struct StyleAppui: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.appuiCharte(configuration.isPressed)
    }
}

extension ButtonStyle where Self == StyleBouton {
    static var plein: StyleBouton { StyleBouton(genre: .plein) }
    static var contour: StyleBouton { StyleBouton(genre: .contour) }
    static var clair: StyleBouton { StyleBouton(genre: .clair) }
}
