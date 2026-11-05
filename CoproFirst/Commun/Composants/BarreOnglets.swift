// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La barre d'onglets d'une page du site, en pastilles qui défilent : un onglet par
/// pastille, `onglet.<id>` pour les tests. Les onglets viennent d'`OngletsDuSite.ouverts`
/// (jamais une liste écrite dans l'écran) — Mes lots & accès, Prestataires, Espace CS.
struct BarreOnglets: View {
    let onglets: [OngletDuSite]
    @Binding var actif: String

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(onglets, id: \.id) { onglet in
                    Pastille(libelle: onglet.libelle, retenue: onglet.id == actif) {
                        withAnimation(.snappy(duration: 0.22)) { actif = onglet.id }
                    }
                    .accessibilityIdentifier("onglet.\(onglet.id)")
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: actif)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Onglets")
    }
}
