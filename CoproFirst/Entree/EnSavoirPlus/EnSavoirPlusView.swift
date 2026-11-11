// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Écran 2 — la page de coprofirst.fr, raccourcie, d'un seul tenant ; les deux portes
/// restent collées en bas. Ses textes sont ceux du site (`contenu.json`, #51).
struct EnSavoirPlusView: View {
    @Environment(Parcours.self) private var parcours
    @Environment(Vitrine.self) private var vitrine
    @Environment(\.palette) private var palette

    var body: some View {
        let page = vitrine.pages.enSavoirPlus
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(page.titre)
                        .font(.titre(.largeTitle))
                        .foregroundStyle(palette.text)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("vitrine.titre")
                    Text(page.chapeau)
                        .font(.title3)
                        .foregroundStyle(palette.textMuted)
                }
                ApercuDuFil()
                VStack(alignment: .leading, spacing: 6) {
                    Text(page.section)
                        .font(.titre(.title2))
                        .foregroundStyle(palette.text)
                        .accessibilityAddTraits(.isHeader)
                    Text(page.sousTitre)
                        .font(.subheadline)
                        .foregroundStyle(palette.textMuted)
                }
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(page.rangees) { rangee in
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Image(systemName: rangee.symbole)
                                .font(.title3)
                                .foregroundStyle(palette.primary)
                                .frame(width: 30)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(rangee.titre).font(.headline).foregroundStyle(palette.text)
                                Text(rangee.ligne).font(.subheadline).foregroundStyle(palette.textMuted)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("vitrine.rangee.\(rangee.id)")
                    }
                }
            }
            .padding(Mise.marge)
        }
        .background(palette.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { PastilleOuSuisJe(installation: nil) }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button(ContenuVitrine.entrer) { parcours.chemin.append(.connexion(.init())) }
                    .buttonStyle(.plein)
                Button(ContenuVitrine.essayerDemo) { parcours.chemin.append(.demo) }
                    .buttonStyle(.contour)
            }
            .padding(.horizontal, Mise.marge)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }
}

/// « Une capture » : le fil lui-même, en miniature, rendu par l'app — aucune image
/// du site n'entre dans le dépôt (les captures portent le logo, hors licence).
private struct ApercuDuFil: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Apercu.fil.prefix(3)) { element in
                CarteDuFil(element: element)
            }
        }
        .padding(12)
        .background(palette.neutreFond, in: .rect(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(palette.border, lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Aperçu du fil d'une résidence")
    }
}
