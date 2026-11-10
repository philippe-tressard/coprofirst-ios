// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le filtre « Suivi » en pastilles : « Toutes », puis les états présents — le
/// compte n'apparaît que sur la pastille retenue.
struct PastillesDeSuivi: View {
    @Bindable var etat: EtatAffaires
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                pastille("Toutes", code: nil)
                ForEach(etat.optionsDeSuivi) { option in
                    pastille(option.libelle, code: option.code)
                }
            }
            .padding(.horizontal, Mise.marge)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .listRowInsets(EdgeInsets())
        .textCase(nil)
        .sensoryFeedback(.selection, trigger: etat.filtres.suivi)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Suivi")
    }

    private func pastille(_ libelle: String, code: String?) -> some View {
        let retenue = etat.filtres.suivi == code
        return Pastille(
            libelle: libelle, retenue: retenue,
            compte: retenue && etat.phase == .pret ? etat.liste.count : nil
        ) {
            withAnimation(mouvementReduit ? nil : .snappy) { etat.filtres.suivi = code }
        }
        .accessibilityIdentifier("affaires.suivi.\(code ?? "toutes")")
    }
}

/// Nature et portée, dans un menu de la barre : le pictogramme se remplit quand
/// un filtre est retenu, et dit combien.
struct MenuFiltresAffaires: View {
    @Bindable var etat: EtatAffaires
    @Environment(\.palette) private var palette

    var body: some View {
        Menu {
            Picker("Nature", selection: $etat.filtres.nature) {
                Text("Toutes les natures").tag(String?.none)
                ForEach(TablesAffaires.natures) { nature in
                    Text("\(nature.emoji) \(nature.libelle)").tag(Optional(nature.code))
                }
            }
            if etat.offrirMeConcerne {
                Toggle("Ce qui me concerne", isOn: $etat.filtres.meConcerne)
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle" + (etat.filtres.actifs > 0 ? ".fill" : ""))
                .foregroundStyle(palette.primary)
        }
        .accessibilityLabel("Filtrer")
        .accessibilityValue(etat.filtres.actifs > 0 ? "\(etat.filtres.actifs) filtre(s) retenu(s)" : "Aucun filtre")
        .accessibilityIdentifier("affaires.filtres")
    }
}

/// Hors ligne : dit une fois, en haut, tant que ça dure.
struct BandeauHorsLigne: View {
    /// Le toit sans onde : symbole du catalogue, généré par
    /// `scripts/rendre-symbole-hors-ligne.swift` ; il suit la taille du libellé.
    static let pictogramme = "hors-ligne"
    @Environment(\.palette) private var palette
    var body: some View {
        Label("Hors ligne — les affaires affichées peuvent dater.", image: Self.pictogramme)
            .font(.footnote.weight(.medium))
            .foregroundStyle(palette.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.bar)
    }
}
