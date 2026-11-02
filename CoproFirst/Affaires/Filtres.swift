// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La rangée de pastilles ; le compte n'apparaît que sur la pastille retenue.
struct Filtres: View {
    @Bindable var etat: EtatAffaires
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(FiltreAffaires.allCases) { filtre in
                    Pastille(
                        libelle: filtre.libelle,
                        retenue: etat.filtre == filtre,
                        compte: etat.filtre == filtre && etat.phase == .pret ? etat.retenues.count : nil
                    ) {
                        withAnimation(mouvementReduit ? nil : .snappy) { etat.filtre = filtre }
                    }
                }
            }
            .padding(.horizontal, Mise.marge)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .listRowInsets(EdgeInsets())
        .textCase(nil)
        .sensoryFeedback(.selection, trigger: etat.filtre)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filtres")
    }
}

/// Hors ligne : dit une fois, en haut, tant que ça dure.
struct BandeauHorsLigne: View {
    @Environment(\.palette) private var palette
    var body: some View {
        Label("Hors ligne — les affaires affichées peuvent dater.", systemImage: "wifi.slash")
            .font(.footnote.weight(.medium))
            .foregroundStyle(palette.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.bar)
    }
}

/// La feuille de création : le formulaire arrive dans un prochain lot.
struct NouvelleAffaireView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Bientôt",
                systemImage: "square.and.pencil",
                description: Text("Signaler un problème depuis l'app arrive dans une prochaine version.")
            )
            .navigationTitle("Nouvelle affaire")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
