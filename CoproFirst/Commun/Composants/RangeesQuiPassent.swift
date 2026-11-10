// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Des capsules qui passent à la ligne quand la place manque — les spécialités d'un
/// prestataire, les pastilles d'un compte (#16).
struct FlowCapsules<Contenu: View>: View {
    @ViewBuilder let contenu: () -> Contenu

    var body: some View {
        RangeesQuiPassent(espacement: 6) { contenu() }
    }
}

/// Une mise en page qui range ses éléments en lignes, et passe à la suivante au bord.
struct RangeesQuiPassent: Layout {
    var espacement: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let largeur = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var hauteurLigne: CGFloat = 0
        var plusLarge: CGFloat = 0
        for vue in subviews {
            let taille = vue.sizeThatFits(.unspecified)
            if x > 0, x + taille.width > largeur {
                y += hauteurLigne + espacement
                x = 0
                hauteurLigne = 0
            }
            x += taille.width + espacement
            hauteurLigne = max(hauteurLigne, taille.height)
            plusLarge = max(plusLarge, x - espacement)
        }
        return CGSize(width: min(plusLarge, largeur), height: y + hauteurLigne)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var hauteurLigne: CGFloat = 0
        for vue in subviews {
            let taille = vue.sizeThatFits(.unspecified)
            if x > bounds.minX, x + taille.width > bounds.maxX {
                y += hauteurLigne + espacement
                x = bounds.minX
                hauteurLigne = 0
            }
            vue.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(taille))
            x += taille.width + espacement
            hauteurLigne = max(hauteurLigne, taille.height)
        }
    }
}
