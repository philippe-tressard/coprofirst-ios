// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Écran 1 — « le sceau » : le nom, une devise, deux portes.
struct AccueilView: View {
    @Environment(Parcours.self) private var parcours
    @Environment(Vitrine.self) private var vitrine
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @State private var apparu = false

    var body: some View {
        // Le sceau tient l'écran ; quand le texte grandit, il défile au lieu de tronquer.
        GeometryReader { cadre in
            ScrollView {
                sceau.frame(minHeight: cadre.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(palette.bg)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Une seule entrée, à la première ouverture : le sceau se pose.
            withAnimation(.smooth(duration: 0.5)) { apparu = true }
        }
        // La porte de la vitrine : son contenu se relit ici, avant qu'on la passe (#51).
        .task { await vitrine.actualiser() }
    }

    private var sceau: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            VStack(spacing: 20) {
                Medaillon(cote: 112)
                    .accessibilityHidden(true)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                Text(ContenuVitrine.nom)
                    .font(.titre(.largeTitle))
                    .foregroundStyle(palette.primary)
                    .accessibilityAddTraits(.isHeader)
                Capsule()
                    .fill(palette.accent)
                    .frame(width: 48, height: 3)
                    .accessibilityHidden(true)
                Text(ContenuVitrine.devise)
                    .font(.titre(.title3))
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Mise.marge)
            .opacity(apparu ? 1 : 0)
            .offset(y: apparu || mouvementReduit ? 0 : 12)
            Spacer(minLength: 24)
            VStack(spacing: 12) {
                Button(ContenuVitrine.entrer) {
                    parcours.chemin.append(.connexion(.init()))
                }
                .buttonStyle(.plein)
                .accessibilityIdentifier("accueil.entrer")
                Button(ContenuVitrine.decouvrirDemo) { parcours.chemin.append(.demo) }
                    .buttonStyle(.contour)
                    .accessibilityIdentifier("accueil.demo")
                Button(ContenuVitrine.enSavoirPlus) { parcours.chemin.append(.enSavoirPlus) }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(palette.primary)
                    .frame(minHeight: Mise.cible)
            }
            .padding(.horizontal, Mise.marge)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }
}
