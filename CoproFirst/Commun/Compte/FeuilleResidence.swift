// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La pastille « où suis-je » touchée : la résidence ouverte, les rôles qu'on y a et
/// « Se déconnecter » ; puis les autres résidences, chacune avec SES rôles.
struct FeuilleResidence: View {
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var geste: GesteDeSortie?

    var body: some View {
        NavigationStack {
            List {
                if let ouverte = parcours.ouverteAJour {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                LogoResidence(installation: ouverte).frame(width: 44, height: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ouverte.nom).font(.headline).foregroundStyle(palette.text)
                                    Text(ouverte.hote).font(.subheadline).foregroundStyle(palette.textMuted)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            PastillesRoles(profil: ouverte.profil)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(palette.surface)
                        Button(role: .destructive) {
                            geste = .deconnecter(ouverte)
                        } label: {
                            Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(palette.danger)
                                .frame(minHeight: Mise.cible)
                        }
                        .accessibilityIdentifier("residence.deconnecter")
                        .listRowBackground(palette.surface)
                    } header: {
                        Text("Vous êtes ici")
                    }
                }
                let autres = parcours.connues.liste.filter { $0.adresse != parcours.ouverte?.adresse }
                if !autres.isEmpty {
                    Section("Mes autres résidences") {
                        ForEach(autres) { installation in
                            Button {
                                parcours.changer(pour: installation)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    LigneResidence(installation: installation)
                                    PastillesRoles(profil: installation.profil)
                                }
                            }
                            .listRowBackground(palette.surface)
                        }
                    }
                }
                Section {
                    Button {
                        parcours.changer(pour: nil)
                    } label: {
                        Label("Une autre résidence", systemImage: "plus.circle.fill")
                            .foregroundStyle(palette.primary)
                            .frame(minHeight: Mise.cible)
                    }
                    .listRowBackground(palette.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            .navigationTitle("Résidences")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDeSortie($geste, parcours: parcours)
            .task { await parcours.rafraichirProfil() }
        }
    }
}
