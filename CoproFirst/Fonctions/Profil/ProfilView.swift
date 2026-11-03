// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Plus › Profil : la résidence et les rôles, puis tout en bas les gestes de sortie —
/// « Se déconnecter » en rouge, « Oublier toutes les résidences » plus discret.
struct ProfilView: View {
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var geste: GesteDeSortie?

    var body: some View {
        List {
            if let ouverte = parcours.ouverteAJour {
                Section("Résidence") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(ouverte.nom).font(.headline).foregroundStyle(palette.text)
                        if let logement = ouverte.profil?.libelleLogement, !logement.isEmpty {
                            Label(logement, systemImage: "mappin").font(.subheadline).foregroundStyle(palette.textMuted)
                        }
                        PastillesRoles(profil: ouverte.profil)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(palette.surface)
                }
                Section {
                    Button(role: .destructive) {
                        geste = .deconnecter(ouverte)
                    } label: {
                        Text("Se déconnecter").frame(maxWidth: .infinity, minHeight: Mise.cible)
                    }
                    .accessibilityIdentifier("profil.deconnecter")
                    .listRowBackground(palette.surface)
                } footer: {
                    Button("Oublier toutes les résidences") { geste = .oublierTout }
                        .font(.footnote)
                        .foregroundStyle(palette.textMuted)
                        .frame(maxWidth: .infinity, minHeight: Mise.cible)
                        .padding(.top, 8)
                        .accessibilityIdentifier("profil.oublierTout")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.bg)
        .navigationTitle("Profil")
        .confirmationDeSortie($geste, parcours: parcours)
        .task { await parcours.rafraichirProfil() }
    }
}
