// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Un composant tiers et ses textes entiers : l'avis doit accompagner chaque copie.
struct LicencesTiercesView: View {
    @Environment(\.palette) private var palette
    let composant: ComposantTiers

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Mise.marge) {
                Text(composant.role)
                    .font(.body).foregroundStyle(palette.text)
                ForEach(Array(composant.lus().enumerated()), id: \.offset) { _, texte in
                    Text(texte)
                        .font(.footnote.monospaced())
                        .foregroundStyle(palette.textMuted)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Mise.marge)
        }
        .background(palette.bg)
        .navigationTitle(composant.nom)
        .navigationBarTitleDisplayMode(.inline)
    }
}
