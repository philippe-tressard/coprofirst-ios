// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Une résidence déjà connue : pictogramme, nom, adresse, chevron.
struct LigneResidence: View {
    let installation: Installation

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "building.2.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Charte.primary)
                .frame(width: 40, height: 40)
                .background(Charte.primaryLight, in: .rect(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(installation.nom)
                    .font(.headline)
                    .foregroundStyle(Charte.text)
                Text(installation.hote)
                    .font(.subheadline)
                    .foregroundStyle(Charte.textMuted)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Charte.textMuted)
                .accessibilityHidden(true)
        }
        .frame(minHeight: Mise.cible)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Ouvre la connexion à cette résidence")
    }
}
