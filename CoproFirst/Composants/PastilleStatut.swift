// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le statut d'une affaire, en pastille : le libellé et la teinte du site
/// (`StatutsAffaire`, généré depuis tickets.ts ; la classe `badge-*` y désigne la
/// couleur d'état de la charte).
struct PastilleStatut: View {
    let statut: String
    @Environment(\.palette) private var palette

    var body: some View {
        let (libelle, pastille) = StatutsAffaire.parCode[statut] ?? (statut, "badge-gray")
        let (texte, fond) = teintes(pastille)
        Text(libelle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette[keyPath: texte])
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(palette[keyPath: fond], in: .capsule)
            .accessibilityLabel(Text("Statut : \(libelle)"))
    }

    private func teintes(_ pastille: String) -> (KeyPath<Palette, Color>, KeyPath<Palette, Color>) {
        switch pastille {
        case "badge-blue": (\.info, \.infoFond)
        case "badge-purple": (\.violet, \.violetFond)
        case "badge-orange": (\.orangeTexte, \.orangeFond)
        case "badge-yellow": (\.jauneTexte, \.jauneFond)
        case "badge-green": (\.successTexte, \.successFond)
        default: (\.textMuted, \.neutreFond)
        }
    }
}
