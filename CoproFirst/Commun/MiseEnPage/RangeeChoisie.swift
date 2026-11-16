// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

extension View {
    /// La rangée de `element` dans la liste d'une `ListeEtFiche` : soulignée quand sa fiche
    /// est ouverte à côté, et dite « sélectionnée » par VoiceOver. En classe compacte, la
    /// fiche couvre la liste : rien à souligner.
    func rangeeChoisie<Element: Hashable>(_ element: Element) -> some View {
        modifier(RangeeChoisie(element: AnyHashable(element)))
    }
}

private struct RangeeChoisie: ViewModifier {
    let element: AnyHashable
    @Environment(\.ficheOuverte) private var ouverte
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        let choisie = ouverte == element
        content
            .overlay {
                if choisie {
                    RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                        .strokeBorder(palette.primary, lineWidth: Mise.filetChoisi)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityAddTraits(choisie ? .isSelected : [])
    }
}

private struct CleFicheOuverte: EnvironmentKey {
    static var defaultValue: AnyHashable? { nil }
}

extension EnvironmentValues {
    /// L'élément dont la fiche est ouverte à côté de la liste (`ListeEtFiche`, classe régulière).
    var ficheOuverte: AnyHashable? {
        get { self[CleFicheOuverte.self] }
        set { self[CleFicheOuverte.self] = newValue }
    }
}
