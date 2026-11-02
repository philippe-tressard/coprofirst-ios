// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Écran 3 — se connecter à la résidence choisie (POST /auth/login, cookies).
struct ConnexionView: View {
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(Reseau.self) private var reseau
    @Environment(\.espaceZoom) private var zoom
    @Environment(\.openURL) private var ouvrirLien
    @State private var email = ""
    @State private var motDePasse = ""
    @State private var enCours = false
    @State private var erreur: ErreurService?
    @State private var reussite = 0
    @FocusState private var champ: Champ?

    private enum Champ { case email, motDePasse }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                EnTeteResidence(installation: installation)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Connectez-vous à votre espace")
                        .font(.titre(.title2))
                        .foregroundStyle(Charte.text)
                        .accessibilityAddTraits(.isHeader)
                    ChampSaisie(
                        libelle: "Adresse électronique",
                        champ: {
                            TextField("vous@exemple.fr", text: $email)
                                .keyboardType(.emailAddress)
                                .textContentType(.username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.next)
                                .focused($champ, equals: .email)
                                .onSubmit { champ = .motDePasse }
                                .accessibilityIdentifier("connexion.email")
                        }, enErreur: erreur == .identifiantsRefuses)
                    ChampSaisie(
                        libelle: "Mot de passe",
                        champ: {
                            SecureField("Votre mot de passe", text: $motDePasse)
                                .textContentType(.password)
                                .submitLabel(.go)
                                .focused($champ, equals: .motDePasse)
                                .onSubmit { Task { await seConnecter() } }
                                .accessibilityIdentifier("connexion.motDePasse")
                        }, enErreur: erreur == .identifiantsRefuses)
                    HStack {
                        Spacer()
                        Button("Mot de passe oublié ?") {
                            ouvrirLien(installation.adresse.appending(path: "auth/mot-de-passe-oublie"))
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Charte.primary)
                        .frame(minHeight: Mise.cible)
                    }
                    if let erreur {
                        MessageErreur(texte: erreur.phrase)
                    }
                }
                Label {
                    Text("À la prochaine ouverture, Face ID vous évitera de saisir votre mot de passe.")
                } icon: {
                    Image(systemName: "faceid")
                        .foregroundStyle(Charte.primary)
                }
                .font(.footnote)
                .foregroundStyle(Charte.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Mise.marge)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Charte.bg)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await seConnecter() }
            } label: {
                HStack(spacing: 8) {
                    if enCours { ProgressView().tint(Charte.surPlein) }
                    Text("Se connecter")
                }
            }
            .buttonStyle(.plein)
            .disabled(email.isEmpty || motDePasse.isEmpty || enCours)
            .accessibilityIdentifier("connexion.valider")
            .padding(.horizontal, Mise.marge)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .destinationZoom(id: installation.id, dans: zoom)
        .sensoryFeedback(.success, trigger: reussite)
        .sensoryFeedback(.error, trigger: erreur) { _, nouvelle in nouvelle != nil }
        .task { await reprendreSiGardee() }
    }

    private func seConnecter() async {
        guard reseau.enLigne else { return montrer(.horsLigne) }
        champ = nil
        enCours = true
        defer { enCours = false }
        do {
            try await parcours.service.connecter(installation, email: email, motDePasse: motDePasse)
            reussite += 1
            motDePasse = ""
            parcours.ouvrir(installation)
        } catch {
            montrer(ErreurService.depuis(error))
        }
    }

    /// Une session gardée au Trousseau : Face ID, puis l'espace — sans mot de passe.
    private func reprendreSiGardee() async {
        guard parcours.service.aUneSessionGardee(installation) else { return }
        do {
            try await parcours.service.reprendre(installation)
            reussite += 1
            parcours.ouvrir(installation)
        } catch {
            champ = .email
        }
    }

    private func montrer(_ nouvelle: ErreurService) {
        withAnimation(.snappy) { erreur = nouvelle }
    }
}

/// Le logo et le nom de la résidence, lus dans GET /config.
private struct EnTeteResidence: View {
    let installation: Installation

    var body: some View {
        VStack(spacing: 12) {
            Group {
                if let logo = installation.adresseLogo {
                    AsyncImage(url: logo) { image in
                        image.resizable().scaledToFit().frame(width: 72, height: 72)
                    } placeholder: {
                        Medaillon(cote: 72)
                    }
                } else {
                    Medaillon(cote: 72)
                }
            }
            .accessibilityHidden(true)
            Text(installation.nom)
                .font(.titre(.title))
                .foregroundStyle(Charte.text)
                .multilineTextAlignment(.center)
            Text(installation.hote)
                .font(.subheadline)
                .foregroundStyle(Charte.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}
