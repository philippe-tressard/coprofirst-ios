// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Écran 2 — l'adresse de la résidence : saisie, scannée, ou déjà connue. Aucun annuaire.
struct ResidenceView: View {
    @Environment(Parcours.self) private var parcours
    @Environment(Reseau.self) private var reseau
    @State private var saisie = ""
    @State private var decouverte = EtatDecouverte()
    @State private var scanner = false
    @State private var qrReconnu = 0
    @FocusState private var champActif: Bool
    @Environment(\.espaceZoom) private var zoom

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Saisissez l'adresse du site de votre résidence, ou scannez le QR code de votre fiche d'arrivée.")
                    .font(.body)
                    .foregroundStyle(Charte.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    ChampSaisie(
                        libelle: "Adresse du site",
                        champ: {
                            TextField("residence.exemple.fr", text: $saisie)
                                .keyboardType(.URL)
                                .textContentType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.go)
                                .focused($champActif)
                                .onSubmit { Task { await continuer() } }
                                .accessibilityIdentifier("residence.adresse")
                        }, enErreur: decouverte.erreur != nil)
                    if let erreur = decouverte.erreur {
                        MessageErreur(texte: erreur.phrase)
                    }
                    Button {
                        scanner = true
                    } label: {
                        Label("Scanner le QR code", systemImage: "qrcode.viewfinder")
                    }
                    .buttonStyle(.clair)
                }

                if !parcours.connues.liste.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mes résidences")
                            .styleLibelle()
                            .accessibilityAddTraits(.isHeader)
                        Carte {
                            VStack(spacing: 0) {
                                ForEach(parcours.connues.liste) { installation in
                                    Button {
                                        parcours.chemin.append(.connexion(installation))
                                    } label: {
                                        LigneResidence(installation: installation)
                                    }
                                    .buttonStyle(.plain)
                                    .sourceZoom(id: installation.id, dans: zoom)
                                    if installation != parcours.connues.liste.last {
                                        Divider().overlay(Charte.border)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(Mise.marge)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Charte.bg)
        .navigationTitle("Votre résidence")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await continuer() }
            } label: {
                HStack(spacing: 8) {
                    if decouverte.enCours { ProgressView().tint(Charte.surPlein) }
                    Text("Continuer")
                }
            }
            .buttonStyle(.plein)
            .disabled(saisie.trimmingCharacters(in: .whitespaces).isEmpty || decouverte.enCours)
            .accessibilityIdentifier("residence.continuer")
            .padding(.horizontal, Mise.marge)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .sheet(isPresented: $scanner) {
            ScannerQRView { texte in
                scanner = false
                saisie = texte
                qrReconnu += 1
                Task { await continuer() }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sensoryFeedback(.success, trigger: qrReconnu)
        .sensoryFeedback(.error, trigger: decouverte.erreur) { _, nouvelle in nouvelle != nil }
    }

    private func continuer() async {
        guard reseau.enLigne else { return decouverte.signaler(.horsLigne) }
        guard let adresse = AdresseInstallation.normaliser(saisie) else {
            return decouverte.signaler(.pasCoproFirst)
        }
        champActif = false
        if let installation = await decouverte.decouvrir(adresse, avec: parcours.service) {
            parcours.connues.retenir(installation)
            parcours.chemin.append(.connexion(installation))
        }
    }
}
