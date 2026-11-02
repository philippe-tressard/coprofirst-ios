// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Un champ de la charte : libellé en capitales au-dessus, contour visible à 3:1.
struct ChampSaisie<Champ: View>: View {
    let libelle: String
    @ViewBuilder let champ: () -> Champ
    var enErreur = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(libelle)
                .styleLibelle()
                .accessibilityHidden(true)
            champ()
                .font(.body)
                .foregroundStyle(Charte.text)
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .background(Charte.surface, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                        .strokeBorder(enErreur ? Charte.danger : Charte.borderChamp, lineWidth: 1)
                }
                .accessibilityLabel(Text(libelle.capitalized(with: Locale(identifier: "fr_FR"))))
        }
    }
}
