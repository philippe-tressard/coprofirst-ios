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
///
/// Un élément plus large que la rangée (une longue pastille, un grand texte) prend une
/// ligne à lui, à la largeur de la rangée : il y passe à la ligne au lieu de déborder de
/// sa carte (#191). La mesure et le placement lisent la même `miseEnPage`.
struct RangeesQuiPassent: Layout {
    var espacement: CGFloat = 6

    struct MiseEnPage: Equatable {
        var cadres: [CGRect]
        var taille: CGSize
    }

    /// Les cadres des éléments, mesurés par `mesures` (une proposition → une taille), dans
    /// une rangée de `largeur` (`nil` : sans limite).
    static func miseEnPage(
        _ mesures: [(ProposedViewSize) -> CGSize], largeur: CGFloat?, espacement: CGFloat
    ) -> MiseEnPage {
        let limite = largeur ?? .infinity
        var cadres: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var hauteurLigne: CGFloat = 0
        var plusLarge: CGFloat = 0
        for mesure in mesures {
            var taille = mesure(.unspecified)
            if taille.width > limite {
                // Plus large que la rangée : sa largeur à elle, et la hauteur qu'il y prend.
                taille = mesure(ProposedViewSize(width: limite, height: nil))
                taille.width = min(taille.width, limite)
            }
            if x > 0, x + taille.width > limite {
                y += hauteurLigne + espacement
                x = 0
                hauteurLigne = 0
            }
            cadres.append(CGRect(origin: CGPoint(x: x, y: y), size: taille))
            x += taille.width + espacement
            hauteurLigne = max(hauteurLigne, taille.height)
            plusLarge = max(plusLarge, x - espacement)
        }
        return MiseEnPage(cadres: cadres, taille: CGSize(width: min(plusLarge, limite), height: y + hauteurLigne))
    }

    private func miseEnPage(_ subviews: Subviews, largeur: CGFloat?) -> MiseEnPage {
        Self.miseEnPage(subviews.map { vue in { vue.sizeThatFits($0) } }, largeur: largeur, espacement: espacement)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        miseEnPage(subviews, largeur: proposal.width).taille
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let mise = miseEnPage(subviews, largeur: bounds.width)
        for (vue, cadre) in zip(subviews, mise.cadres) {
            vue.place(
                at: CGPoint(x: bounds.minX + cadre.minX, y: bounds.minY + cadre.minY),
                proposal: ProposedViewSize(cadre.size))
        }
    }
}
