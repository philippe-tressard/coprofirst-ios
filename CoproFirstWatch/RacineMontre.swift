// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La racine : la cloche si la montre est reliée, sinon la phrase qui dit de la relier.
struct RacineMontre: View {
    let liaison: LiaisonDeLaMontre
    @Environment(\.scenePhase) private var phase

    var body: some View {
        Group {
            switch liaison.etat {
            case .nonReliee:
                ScrollView {
                    Text(TextesMontre.nonReliee)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("montre.nonReliee")
                }
            case .reliee(let residence, let source):
                ClocheView(
                    residence: residence, adresse: source.adresse,
                    lecteur: liaison.lecteur(source)
                )
                // Une autre résidence, ou un jeton renouvelé : une cloche neuve, sans l'ancienne liste.
                .id(source)
            }
        }
        // Une liaison échue pendant que la montre dormait ne lit plus rien.
        .onChange(of: phase) { _, apres in
            if apres == .active { liaison.relire() }
        }
    }
}
