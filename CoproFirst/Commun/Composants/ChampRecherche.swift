// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le champ de recherche d'une liste, dans la page (et non dans la barre de
/// navigation : il ne vaut que pour l'onglet qui le porte). La règle de recherche :
/// `Recherche.contientTousLesMots`.
struct ChampRecherche: View {
    @Binding var texte: String
    /// Ce que l'on peut y chercher (« Nom, métier, équipement… »).
    let indication: String
    let identifiant: String
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(palette.textMuted).accessibilityHidden(true)
            TextField(indication, text: $texte)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier(identifiant)
            if !texte.isEmpty {
                Button { texte = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .foregroundStyle(palette.textMuted)
                    .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: Mise.cible)
        .background(palette.surface, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                .strokeBorder(palette.borderChamp, lineWidth: 1)
        }
    }
}
