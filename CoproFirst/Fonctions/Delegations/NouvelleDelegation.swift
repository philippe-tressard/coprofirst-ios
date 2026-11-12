// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Nouvelle délégation aidant » (conseil syndical) : la personne aidée, son proche
/// aidant, un motif et, au besoin, une date de fin. L'aidant devra l'accepter.
struct NouvelleDelegation: View {
    let service: any ServiceDelegations
    let installation: Installation
    /// La délégation est créée : la liste le dira.
    let creee: () -> Void
    @Environment(\.dismiss) private var fermer
    @Environment(\.palette) private var palette
    @State private var saisie = SaisieDelegation()
    @State private var avecFin = false
    @State private var fin = Date.now.addingTimeInterval(90 * 86_400)
    @State private var residents: [ResidentDelegable] = []
    @State private var residentsEnErreur = false
    @State private var envoi = false
    @State private var erreur: ErreurService?

    var body: some View {
        Form {
            if residentsEnErreur {
                Section { MessageErreur(texte: TextesDelegations.residentsIndisponibles) }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section {
                choix(TextesDelegations.mandant, $saisie.mandant, parmi: actifs)
                    .accessibilityIdentifier("nouvelle-delegation.mandant")
                choix(TextesDelegations.procheAidant, $saisie.aidant, parmi: actifs.filter { $0.id != saisie.mandant })
                    .accessibilityIdentifier("nouvelle-delegation.aidant")
            }
            Section(TextesDelegations.motif) {
                TextField(TextesDelegations.motifExemple, text: $saisie.motif)
                    .accessibilityIdentifier("nouvelle-delegation.motif")
            }
            Section {
                Toggle(TextesDelegations.avecDateFin, isOn: $avecFin.animation(.snappy))
                if avecFin {
                    DatePicker(
                        TextesDelegations.dateFin, selection: $fin, in: Date.now..., displayedComponents: .date)
                }
            } footer: {
                if !avecFin { Text(TextesDelegations.sansDate) }
            }
            Section {
                Label(TextesDelegations.avertissement, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(palette.textMuted)
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.bg)
        .navigationTitle(TextesDelegations.titreFormulaire)
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(envoi)
        .safeAreaInset(edge: .top) {
            if let erreur { MessageErreur(texte: erreur.phrase).padding(.horizontal, Mise.marge) }
        }
        .animation(.snappy, value: erreur)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(TextesDelegations.annuler) { fermer() } }
            ToolbarItem(placement: .confirmationAction) {
                if envoi {
                    ProgressView()
                } else {
                    Button(TextesDelegations.enregistrer, action: enregistrer)
                        .fontWeight(.semibold)
                        .disabled(!saisie.complete)
                        .accessibilityIdentifier("nouvelle-delegation.enregistrer")
                }
            }
        }
        .onChange(of: saisie.mandant) { _, mandant in
            if saisie.aidant == mandant { saisie.aidant = nil }
        }
        .task {
            do {
                residents = try await service.residentsDelegables(installation)
            } catch {
                residentsEnErreur = true
            }
        }
    }

    /// Les comptes actifs : seuls ils peuvent être liés (le formulaire du site).
    private var actifs: [ResidentDelegable] { residents.filter(\.actif) }

    private func choix(_ titre: String, _ valeur: Binding<Int?>, parmi comptes: [ResidentDelegable]) -> some View {
        Picker(titre, selection: valeur) {
            Text(TextesDelegations.choisir).tag(Int?.none)
            ForEach(comptes) { compte in
                Text("\(compte.nomAffiche) (\(compte.email))").tag(Int?.some(compte.id))
            }
        }
        .pickerStyle(.navigationLink)
    }

    private func enregistrer() {
        var envoyee = saisie
        envoyee.dateFin = avecFin ? fin : nil
        envoi = true
        erreur = nil
        Task {
            do {
                _ = try await service.creerDelegation(envoyee, dans: installation)
                creee()
                fermer()
            } catch {
                self.erreur = ErreurService.depuis(error)
            }
            envoi = false
        }
    }
}
