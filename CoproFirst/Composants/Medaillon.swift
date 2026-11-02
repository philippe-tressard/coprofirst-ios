// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le pictogramme de CoproFirst dans son carré d'or. Il grandit avec le texte, sans
/// déborder : le carré suit Dynamic Type (`@ScaledMetric`), le symbole s'y ajuste.
struct Medaillon: View {
    @ScaledMetric private var cote: CGFloat
    private let rayon: CGFloat

    init(cote: CGFloat) {
        _cote = ScaledMetric(wrappedValue: cote, relativeTo: .title)
        rayon = cote / 4
    }

    var body: some View {
        Image(systemName: "building.2.fill")
            .resizable()
            .scaledToFit()
            .fontWeight(.semibold)
            .foregroundStyle(Charte.surAccent)
            .padding(cote * 0.24)
            .frame(width: cote, height: cote)
            .background(Charte.accent, in: .rect(cornerRadius: rayon, style: .continuous))
            .accessibilityHidden(true)
    }
}
