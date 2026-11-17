// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

extension View {
    /// La rangée de `element` dans la liste d'une `ListeEtFiche` : soulignée quand sa fiche
    /// est ouverte à côté, et dite « sélectionnée » par VoiceOver. En classe compacte, la
    /// fiche couvre la liste : rien à souligner.
    ///
    /// `debord` : un lien dans le texte (le syndic, une annexe) — le filet s'écarte de ses
    /// lettres ; une carte le porte à son bord (0).
    func rangeeChoisie<Element: Hashable>(_ element: Element, debord: CGFloat = 0) -> some View {
        modifier(RangeeChoisie(element: AnyHashable(element), debord: debord))
    }

    /// Une rangée de `List` : le filet se pose sur son fond (`fond`, à la place de
    /// `listRowBackground`), au bord de la rangée et non autour de son contenu.
    func rangeeDeListeChoisie<Element: Hashable>(_ element: Element, fond: Color) -> some View {
        modifier(RangeeDeListeChoisie(element: AnyHashable(element), fond: fond))
    }

    /// Une rangée qui n'ouvre une fiche que parfois (une entrée du carnet liée à une affaire).
    func rangeeChoisie<Element: Hashable>(_ element: Element?) -> some View {
        modifier(RangeeChoisie(element: element.map(AnyHashable.init), debord: 0))
    }
}

private struct RangeeChoisie: ViewModifier {
    let element: AnyHashable?
    let debord: CGFloat
    @Environment(\.ficheOuverte) private var ouverte
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        let choisie = element != nil && ouverte == element
        content
            .overlay {
                if choisie {
                    RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                        .strokeBorder(palette.primary, lineWidth: Mise.filetChoisi)
                        .padding(.horizontal, -debord)
                        .padding(.vertical, -debord / 2)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityAddTraits(choisie ? .isSelected : [])
    }
}

private struct RangeeDeListeChoisie: ViewModifier {
    let element: AnyHashable
    let fond: Color
    @Environment(\.ficheOuverte) private var ouverte
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        let choisie = ouverte == element
        content
            .listRowBackground(
                fond.overlay {
                    if choisie { Rectangle().strokeBorder(palette.primary, lineWidth: Mise.filetChoisi) }
                }
            )
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
