// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Une pastille de filtre. Le compte ne s'affiche que sur la pastille retenue.
struct Pastille: View {
    let libelle: String
    let retenue: Bool
    var compte: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(libelle)
                if retenue, let compte {
                    Text(compte, format: .number)
                        .monospacedDigit()
                        .fontWeight(.bold)
                }
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .frame(minHeight: Mise.cible)
            .foregroundStyle(retenue ? Charte.surPlein : Charte.text)
            .background(retenue ? Charte.primaryPlein : Charte.surface, in: .capsule)
            .overlay {
                if !retenue {
                    Capsule().strokeBorder(Charte.border, lineWidth: 1)
                }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        // Le libellé reste le nom du filtre ; le compte est sa valeur.
        .accessibilityLabel(libelle)
        .accessibilityAddTraits(retenue ? .isSelected : [])
        .accessibilityValue(retenue && compte != nil ? Text("\(compte ?? 0) affaires") : Text(""))
    }
}
