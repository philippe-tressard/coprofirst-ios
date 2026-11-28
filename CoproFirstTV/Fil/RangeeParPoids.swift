// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Une rangée de tuiles qui se partagent TOUTE la largeur selon leur poids
/// (`TuileDuHall.poids`) : une tuile absente laisse sa place à ses voisines, aucune case vide.
struct RangeeParPoids: Layout {
    let ecart: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let poids = subviews.map { $0[PoidsDansLaRangee.self] }
        let total = poids.reduce(0, +)
        guard total > 0 else { return }
        let utile = bounds.width - ecart * CGFloat(max(0, subviews.count - 1))
        var x = bounds.minX
        for (tuile, part) in zip(subviews, poids) {
            let largeur = utile * part / total
            tuile.place(
                at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading,
                proposal: ProposedViewSize(width: largeur, height: bounds.height))
            x += largeur + ecart
        }
    }
}

/// Le poids d'une tuile dans sa rangée.
struct PoidsDansLaRangee: LayoutValueKey {
    static let defaultValue: Double = 1
}
