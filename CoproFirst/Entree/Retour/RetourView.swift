// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le retour d'un habitué dont la session est gardée sous Face ID : la résidence, et
/// Face ID demandé dès l'arrivée — un regard, puis le fil. Annulé, il se redemande
/// d'un toucher ; le mot de passe reste à côté. Une session que le serveur ne
/// reconnaît plus mène à la connexion, adresse et courriel pré-remplis.
struct RetourView: View {
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @State private var biometrie = Biometrie.actuelle
    @State private var enCours = false
    @State private var tente = false
    @State private var erreur: ErreurService?
    @State private var perdue = false
    @State private var apparu = false

    var body: some View {
        if perdue {
            ConnexionView(preremplissage: .init(installation: installation, parMotDePasse: true))
                .transition(.opacity)
        } else {
            panneau
        }
    }

    private var panneau: some View {
        // Comme l'accueil : l'écran tient, et défile quand le texte grandit.
        GeometryReader { cadre in
            ScrollView {
                contenu.frame(minHeight: cadre.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(palette.bg)
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.error, trigger: erreur) { _, nouvelle in nouvelle != nil }
        .onAppear { withAnimation(.smooth(duration: 0.5)) { apparu = true } }
        // Une seule demande d'office : revenu du mot de passe, l'utilisateur choisit.
        .task {
            guard !tente else { return }
            tente = true
            await ouvrir()
        }
    }

    private var contenu: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            VStack(spacing: 16) {
                LogoRetour(installation: installation)
                Text(installation.nom)
                    .font(.titre(.largeTitle))
                    .foregroundStyle(palette.primary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("retour.residence")
                Text(installation.hote)
                    .font(.subheadline)
                    .foregroundStyle(palette.textMuted)
            }
            .padding(.horizontal, Mise.marge)
            .opacity(apparu ? 1 : 0)
            .offset(y: apparu || mouvementReduit ? 0 : 12)
            Spacer(minLength: 24)
            VStack(spacing: 12) {
                if let erreur { MessageErreur(texte: erreur.phrase) }
                Button {
                    Task { await ouvrir() }
                } label: {
                    HStack(spacing: 8) {
                        if enCours {
                            ProgressView().tint(palette.surPlein)
                        } else {
                            Image(systemName: biometrie.symbole).accessibilityHidden(true)
                        }
                        Text(biometrie.ouvrir)
                    }
                }
                .buttonStyle(.plein)
                .disabled(enCours)
                .accessibilityIdentifier("retour.ouvrir")
                Button("Utiliser le mot de passe") {
                    parcours.chemin.append(.connexion(.init(installation: installation, parMotDePasse: true)))
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(palette.primary)
                .frame(minHeight: Mise.cible)
                .accessibilityIdentifier("retour.motDePasse")
            }
            .padding(.horizontal, Mise.marge)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private func ouvrir() async {
        guard !enCours else { return }
        enCours = true
        defer { enCours = false }
        withAnimation(.snappy) { erreur = nil }
        do {
            try await parcours.service.reprendre(installation)
            parcours.ouvrir(installation)
        } catch {
            if parcours.service.aUneSessionGardee(installation) {
                // Face ID annulé, ou serveur injoignable : la session reste gardée.
                // Une annulation ne se commente pas ; une panne se dit en une phrase.
                let cause = ErreurService.depuis(error)
                if cause != .sessionExpiree { withAnimation(.snappy) { erreur = cause } }
            } else {
                // Le serveur a refusé le jeton (expiré, révoqué) : le Trousseau est vidé.
                parcours.avis = ErreurService.sessionExpiree.phrase
                withAnimation(.smooth(duration: 0.35)) { perdue = true }
            }
        }
    }
}

/// Le logo de la résidence (ou celui de CoproFirst), à la taille du médaillon de
/// l'accueil, qui suit Dynamic Type sans déborder.
private struct LogoRetour: View {
    let installation: Installation
    @ScaledMetric(relativeTo: .title) private var cote: CGFloat = 96

    var body: some View {
        LogoResidence(installation: installation)
            .frame(width: min(cote, 160), height: min(cote, 160))
    }
}
