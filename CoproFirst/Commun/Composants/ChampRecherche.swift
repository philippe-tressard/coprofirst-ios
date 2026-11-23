// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le champ de recherche d'une liste, dans la page (et non dans la barre de
/// navigation : il ne vaut que pour l'onglet qui le porte). La règle de recherche :
/// `Recherche.contientTousLesMots`. ⌘F au clavier matériel y place le curseur (#223).
struct ChampRecherche: View {
    @Binding var texte: String
    /// Ce que l'on peut y chercher (« Nom, métier, équipement… »).
    let indication: String
    let identifiant: String
    @Environment(\.palette) private var palette
    @FocusState private var actif: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(palette.textMuted).accessibilityHidden(true)
            TextField(indication, text: $texte)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($actif)
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
        .rechercheAuClavier { actif = true }
    }
}

extension View {
    /// La recherche d'une liste dans la barre de navigation (`searchable`), et ⌘F au
    /// clavier matériel qui l'ouvre (#223, `RechercheAuClavier.swift`).
    func barreDeRecherche(_ texte: Binding<String>, invite: String) -> some View {
        modifier(BarreDeRecherche(texte: texte, invite: invite))
    }
}

private struct BarreDeRecherche: ViewModifier {
    @Binding var texte: String
    let invite: String
    @State private var ouverte = false

    func body(content: Content) -> some View {
        content
            .searchable(text: $texte, isPresented: $ouverte, prompt: invite)
            .rechercheAuClavier { ouverte = true }
    }
}
