// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les trois boutons de la charte : plein (l'action principale), contour, clair.
enum GenreBouton {
    case plein, contour, clair
}

struct StyleBouton: ButtonStyle {
    let genre: GenreBouton
    @Environment(\.isEnabled) private var actif
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit

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
                        .strokeBorder(Charte.primary, lineWidth: 1.5)
                }
            }
            .opacity(actif ? 1 : 0.45)
            // Le retour au toucher : un appui se voit à l'instant, et se défait aussitôt.
            .scaleEffect(configuration.isPressed && !mouvementReduit ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
            .contentShape(.rect(cornerRadius: Mise.rayon))
    }

    private var premierPlan: Color {
        switch genre {
        case .plein: Charte.surPlein
        case .contour, .clair: Charte.primary
        }
    }

    private var fond: Color {
        switch genre {
        case .plein: Charte.primaryPlein
        case .contour: .clear
        case .clair: Charte.primaryLight
        }
    }
}

extension ButtonStyle where Self == StyleBouton {
    static var plein: StyleBouton { StyleBouton(genre: .plein) }
    static var contour: StyleBouton { StyleBouton(genre: .contour) }
    static var clair: StyleBouton { StyleBouton(genre: .clair) }
}
