// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Écran 5 — la démonstration : trois personnages, un toucher pour entrer.
/// ⚠️ Pas encore vu par Philippe.
struct DemoView: View {
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var enCours: String?
    @State private var erreur: ErreurService?
    @Environment(\.dynamicTypeSize) private var tailleTexte

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(ContenuVitrine.titreDemo)
                        .font(.titre(.largeTitle))
                        .foregroundStyle(palette.text)
                        .accessibilityAddTraits(.isHeader)
                    Text(ContenuVitrine.chapeauDemo)
                        .font(.body)
                        .foregroundStyle(palette.textMuted)
                }
                ForEach(ContenuVitrine.personnages) { personnage in
                    Button {
                        Task { await entrer(personnage) }
                    } label: {
                        CartePersonnage(personnage: personnage, enCours: enCours == personnage.code)
                    }
                    .buttonStyle(.plain)
                    .disabled(enCours != nil)
                    .accessibilityIdentifier("demo.\(personnage.code)")
                }
                if let erreur { MessageErreur(texte: erreur.phrase) }
                if tailleTexte.isAccessibilitySize { avertissement }
            }
            .padding(Mise.marge)
        }
        .background(palette.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { PastilleOuSuisJe(installation: nil) }
        .safeAreaInset(edge: .bottom) {
            if !tailleTexte.isAccessibilitySize {
                avertissement
                    .padding(.horizontal, Mise.marge)
                    .padding(.vertical, 12)
                    .background(.bar)
            }
        }
    }

    /// « Effacée chaque nuit, rien n'est réellement envoyé » — collé en bas, ou dans
    /// la page quand le texte est si grand qu'un bandeau couvrirait l'écran.
    private var avertissement: some View {
        Label(ContenuVitrine.avertissementDemo, systemImage: "flask.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(palette.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func entrer(_ personnage: ContenuVitrine.Personnage) async {
        enCours = personnage.code
        defer { enCours = nil }
        do {
            if let installation = try await parcours.service.entrerEnDemo(personnage.code) {
                parcours.ouvrir(installation)
            } else {
                // Sans route qui serve les identifiants : la connexion, pré-remplie.
                let adresse = AdresseInstallation.normaliser(ContenuVitrine.adresseDemo)
                let demo = adresse.map { Installation(adresse: $0, nom: "Démo", aUnLogo: false) }
                parcours.chemin.append(
                    .connexion(
                        .init(
                            installation: demo,
                            email: "\(personnage.code)@\(ContenuVitrine.adresseDemo)",
                            aide: "Le mot de passe de « \(personnage.role) » est publié sur coprofirst.fr.")))
            }
        } catch {
            withAnimation(.snappy) { erreur = ErreurService.depuis(error) }
        }
    }
}

private struct CartePersonnage: View {
    let personnage: ContenuVitrine.Personnage
    let enCours: Bool
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var tailleTexte

    var body: some View {
        let accessible = tailleTexte.isAccessibilitySize
        // Aux tailles d'accessibilité, le rôle passe sous son pictogramme au lieu de se couper.
        let disposition =
            accessible
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 14))
        Carte {
            disposition {
                Image(systemName: personnage.symbole)
                    .font(.title3)
                    .foregroundStyle(palette.primary)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(width: 44, height: 44)
                    .background(palette.primaryLight, in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(personnage.role).font(.headline).foregroundStyle(palette.text)
                    Text(personnage.ligne).font(.subheadline).foregroundStyle(palette.textMuted)
                }
                if !accessible { Spacer(minLength: 8) }
                if enCours {
                    ProgressView().tint(palette.primary)
                } else if !accessible {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(palette.primary)
                        .accessibilityHidden(true)
                }
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Entrer dans la démonstration")
    }
}
