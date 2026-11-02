// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le logo de CoproFirst (`Logo` du catalogue : le dessin du site, vectoriel, sous
/// LicenseRef-CoproFirst-Logo — jamais modifié). Il grandit avec le texte, sans
/// déborder : le côté suit Dynamic Type (`@ScaledMetric`).
struct Medaillon: View {
    @ScaledMetric private var cote: CGFloat

    init(cote: CGFloat) {
        _cote = ScaledMetric(wrappedValue: cote, relativeTo: .title)
    }

    var body: some View {
        Image("Logo")
            .resizable()
            .scaledToFit()
            .frame(width: cote, height: cote)
            .accessibilityLabel("CoproFirst")
    }
}
