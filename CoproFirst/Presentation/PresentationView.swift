// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Écran 1 — ce qu'est CoproFirst, et les deux façons d'y entrer.
struct PresentationView: View {
    @Environment(Parcours.self) private var parcours
    @State private var demo = EtatDecouverte()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Bandeau()
                VStack(spacing: 12) {
                    ForEach(ContenuVitrine.atouts) { atout in
                        Carte {
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Image(systemName: atout.symbole)
                                    .font(.title3)
                                    .foregroundStyle(Charte.primary)
                                    .frame(width: 28)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(atout.titre)
                                        .font(.titre(.title3))
                                        .foregroundStyle(Charte.text)
                                    Text(atout.ligne)
                                        .font(.subheadline)
                                        .foregroundStyle(Charte.textMuted)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, Mise.marge)
                .padding(.top, 24)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Charte.bg)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if let erreur = demo.erreur {
                    MessageErreur(texte: erreur.phrase)
                }
                Button(ContenuVitrine.entrer) { parcours.chemin.append(.residence) }
                    .buttonStyle(.plein)
                    .accessibilityIdentifier("presentation.entrer")
                Button {
                    Task { await ouvrirDemo() }
                } label: {
                    HStack(spacing: 8) {
                        if demo.enCours { ProgressView().tint(Charte.primary) }
                        Text(ContenuVitrine.demo)
                    }
                }
                .buttonStyle(.contour)
                .disabled(demo.enCours)
            }
            .padding(.horizontal, Mise.marge)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.bar)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.error, trigger: demo.erreur) { _, nouvelle in nouvelle != nil }
    }

    private func ouvrirDemo() async {
        guard let adresse = AdresseInstallation.normaliser(ContenuVitrine.adresseDemo) else { return }
        if let installation = await demo.decouvrir(adresse, avec: parcours.service) {
            parcours.chemin.append(.connexion(installation))
        }
    }
}

/// Le bandeau Bleu Seine : le pictogramme dans son carré d'or, le nom en serif, l'accroche.
private struct Bandeau: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Medaillon(cote: 56)
            Text(ContenuVitrine.nom)
                .font(.titre(.largeTitle))
                .foregroundStyle(Charte.surPlein)
                .accessibilityAddTraits(.isHeader)
            Text(ContenuVitrine.accroche)
                .font(.title3)
                .foregroundStyle(Charte.surPlein.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Mise.marge)
        .padding(.top, 40)
        .padding(.bottom, 32)
        .background(Charte.primaryPlein.ignoresSafeArea(edges: .top))
    }
}
