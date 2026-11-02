// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Écran 3 — un seul écran : la résidence, puis les identifiants. La palette de la
/// résidence s'applique dès qu'elle est reconnue.
struct ConnexionView: View {
    let preremplissage: Parcours.Preremplissage
    @Environment(Parcours.self) private var parcours
    @Environment(Reseau.self) private var reseau
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var ouvrirLien
    @State private var saisieResidence = ""
    @State private var decouverte = EtatDecouverte()
    @State private var email = ""
    @State private var motDePasse = ""
    @State private var voirMotDePasse = false
    @State private var enCours = false
    @State private var erreur: ErreurService?
    @State private var reussite = 0
    @State private var scanner = false
    @FocusState private var champ: Champ?

    private enum Champ { case email, motDePasse }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Connectez-vous à votre espace")
                    .font(.titre(.title))
                    .foregroundStyle(palette.text)
                    .accessibilityAddTraits(.isHeader)
                ChampResidence(
                    saisie: $saisieResidence, reconnue: parcours.reconnue, enCours: decouverte.enCours,
                    erreur: decouverte.erreur, scanner: { scanner = true })
                if let aide = preremplissage.aide { AideDemo(texte: aide) }
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
                    libelle: "Mot de passe", champ: { champMotDePasse }, enErreur: erreur == .identifiantsRefuses)
                Button("Mot de passe oublié ?") { ouvrirSurLeSite("auth/mot-de-passe-oublie") }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(palette.primary)
                    .frame(maxWidth: .infinity, minHeight: Mise.cible, alignment: .trailing)
                    .disabled(parcours.reconnue == nil)
                if let erreur { MessageErreur(texte: erreur.phrase) }
                Button {
                    Task { await seConnecter() }
                } label: {
                    HStack(spacing: 8) {
                        if enCours { ProgressView().tint(palette.surPlein) }
                        Text("Se connecter")
                    }
                }
                .buttonStyle(.plein)
                .disabled(parcours.reconnue == nil || email.isEmpty || motDePasse.isEmpty || enCours)
                .accessibilityIdentifier("connexion.valider")
                HStack(spacing: 4) {
                    Text("Pas encore de compte ?").foregroundStyle(palette.textMuted)
                    Button("Demander l'accès") { ouvrirSurLeSite("auth/inscription") }
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.primary)
                        .disabled(parcours.reconnue == nil)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: Mise.cible)
            }
            .padding(Mise.marge)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(palette.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { PastilleOuSuisJe(installation: parcours.reconnue) }
        .sheet(isPresented: $scanner) {
            ScannerQRView { texte in
                scanner = false
                saisieResidence = texte
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sensoryFeedback(.success, trigger: reussite)
        .sensoryFeedback(.success, trigger: parcours.reconnue?.id) { _, nouvelle in nouvelle != nil }
        .sensoryFeedback(.error, trigger: erreur) { _, nouvelle in nouvelle != nil }
        .task(id: saisieResidence) { await reconnaitre() }
        .onAppear(perform: preremplir)
    }

    @ViewBuilder
    private var champMotDePasse: some View {
        HStack(spacing: 10) {
            Group {
                if voirMotDePasse {
                    TextField("Votre mot de passe", text: $motDePasse)
                } else {
                    SecureField("Votre mot de passe", text: $motDePasse)
                }
            }
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .focused($champ, equals: .motDePasse)
            .onSubmit { Task { await seConnecter() } }
            .accessibilityIdentifier("connexion.motDePasse")
            Button {
                voirMotDePasse.toggle()
            } label: {
                Image(systemName: voirMotDePasse ? "eye.slash" : "eye")
                    .foregroundStyle(palette.textMuted)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: Mise.cible, height: Mise.cible)
            }
            .accessibilityLabel(voirMotDePasse ? "Masquer le mot de passe" : "Afficher le mot de passe")
        }
    }

    private func preremplir() {
        guard saisieResidence.isEmpty else { return }
        saisieResidence = preremplissage.installation?.hote ?? parcours.reconnue?.hote ?? ""
        email = preremplissage.email
    }

    /// L'adresse reconnue un instant après la frappe (GET /config), sans bouton.
    private func reconnaitre() async {
        guard let adresse = AdresseInstallation.normaliser(saisieResidence) else {
            if parcours.reconnue != nil { withAnimation(.snappy) { parcours.reconnue = nil } }
            return
        }
        if parcours.reconnue?.adresse == adresse { return await reprendreSiGardee() }
        try? await Task.sleep(for: .milliseconds(600))
        guard !Task.isCancelled, reseau.enLigne else { return }
        let installation = await decouverte.decouvrir(adresse, avec: parcours.service)
        guard !Task.isCancelled else { return }
        withAnimation(.smooth(duration: 0.4)) { parcours.reconnue = installation }
        if installation != nil { await reprendreSiGardee() }
    }

    /// Une session gardée au Trousseau : Face ID, puis le fil — sans mot de passe.
    private func reprendreSiGardee() async {
        guard let installation = parcours.reconnue, parcours.service.aUneSessionGardee(installation) else { return }
        do {
            try await parcours.service.reprendre(installation)
            parcours.ouvrir(installation)
        } catch {
            champ = .email
        }
    }

    private func seConnecter() async {
        guard let installation = parcours.reconnue else { return }
        guard reseau.enLigne else { return montrer(.horsLigne) }
        champ = nil
        enCours = true
        defer { enCours = false }
        do {
            try await parcours.service.connecter(installation, email: email, motDePasse: motDePasse)
            reussite += 1
            motDePasse = ""
            parcours.ouvrir(installation, premiereConnexion: true)
        } catch {
            montrer(ErreurService.depuis(error))
        }
    }

    private func ouvrirSurLeSite(_ chemin: String) {
        guard let installation = parcours.reconnue else { return }
        ouvrirLien(installation.adresse.appending(path: chemin))
    }

    private func montrer(_ nouvelle: ErreurService) {
        withAnimation(.snappy) { erreur = nouvelle }
    }
}

/// L'aide de la démo : où lire le mot de passe public du personnage choisi.
private struct AideDemo: View {
    let texte: String
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var ouvrirLien

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(texte, systemImage: "info.circle.fill")
                .font(.subheadline)
                .foregroundStyle(palette.text)
            if let page = URL(string: ContenuVitrine.pageIdentifiantsDemo) {
                Button("Voir les identifiants publics") { ouvrirLien(page) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primary)
                    .frame(minHeight: Mise.cible)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.primaryLight, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
    }
}
