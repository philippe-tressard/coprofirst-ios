// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La racine : la cloche si la montre est reliée, sinon la phrase qui dit de la relier.
struct RacineMontre: View {
    let etat: EtatMontre

    var body: some View {
        switch etat {
        case .nonReliee:
            ScrollView {
                Text(TextesMontre.nonReliee)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("montre.nonReliee")
            }
        case .reliee(let residence, let source):
            ClocheView(residence: residence, lecteur: LecteurCloche(source: source))
        }
    }
}
