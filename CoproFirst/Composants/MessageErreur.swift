// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Une erreur dite en une phrase, avec, au besoin, de quoi réessayer.
struct MessageErreur: View {
    let texte: String
    var reessayer: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Charte.danger)
                .accessibilityHidden(true)
            Text(texte)
                .font(.subheadline)
                .foregroundStyle(Charte.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let reessayer {
                Button("Réessayer", action: reessayer)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Charte.primary)
                    .frame(minHeight: Mise.cible)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Charte.dangerFond, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
        .accessibilityElement(children: .combine)
        .transition(.opacity)
    }
}
