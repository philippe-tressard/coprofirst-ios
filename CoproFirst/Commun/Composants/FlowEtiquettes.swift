// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Des étiquettes côte à côte, qui passent à la ligne quand la place manque (grand texte).
/// Lue par la Communauté et le fil des réponses (`Commun/Reponses/`).
struct FlowEtiquettes: Layout {
    var espace: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rangees = ranger(largeur: proposal.width ?? .infinity, subviews)
        let hauteur = rangees.map(\.hauteur).reduce(0, +) + espace * CGFloat(max(rangees.count - 1, 0))
        return CGSize(width: proposal.width ?? rangees.map(\.largeur).max() ?? 0, height: hauteur)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for rangee in ranger(largeur: bounds.width, subviews) {
            var x = bounds.minX
            for indice in rangee.indices {
                let proposition = ProposedViewSize(width: bounds.width, height: nil)
                let taille = subviews[indice].sizeThatFits(proposition)
                subviews[indice].place(
                    at: CGPoint(x: x, y: y + (rangee.hauteur - taille.height) / 2), proposal: proposition)
                x += taille.width + espace
            }
            y += rangee.hauteur + espace
        }
    }

    private struct Rangee {
        var indices: [Int] = []
        var largeur: CGFloat = 0
        var hauteur: CGFloat = 0
    }

    private func ranger(largeur: CGFloat, _ subviews: Subviews) -> [Rangee] {
        var rangees = [Rangee()]
        // Une étiquette ne dépasse jamais la largeur : trop longue, elle passe à la ligne en elle-même.
        let proposition = ProposedViewSize(width: largeur.isFinite ? largeur : nil, height: nil)
        for (indice, vue) in subviews.enumerated() {
            let taille = vue.sizeThatFits(proposition)
            let ajout = rangees[rangees.count - 1].indices.isEmpty ? taille.width : taille.width + espace
            if rangees[rangees.count - 1].largeur + ajout > largeur, !rangees[rangees.count - 1].indices.isEmpty {
                rangees.append(Rangee())
            }
            let derniere = rangees.count - 1
            rangees[derniere].largeur += rangees[derniere].indices.isEmpty ? taille.width : taille.width + espace
            rangees[derniere].hauteur = max(rangees[derniere].hauteur, taille.height)
            rangees[derniere].indices.append(indice)
        }
        return rangees
    }
}
