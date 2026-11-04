// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le choix de la catégorie, en vignettes : ce que l'affaire EST décide de qui la
/// traite. Dans l'ordre du site ; une catégorie du bâti porte le liseré doré du
/// carnet d'entretien.
struct ChoixCategorie: View {
    let categories: [CategorieAffaire]
    @Binding var choisie: String?
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var tailleTexte

    var body: some View {
        let colonnes = [GridItem(.adaptive(minimum: tailleTexte.isAccessibilitySize ? 280 : 150), spacing: 10)]
        LazyVGrid(columns: colonnes, spacing: 10) {
            ForEach(categories) { categorie in
                vignette(categorie)
            }
        }
        .sensoryFeedback(.selection, trigger: choisie)
    }

    private func vignette(_ categorie: CategorieAffaire) -> some View {
        let retenue = choisie == categorie.code
        return Button {
            withAnimation(.snappy(duration: 0.2)) { choisie = categorie.code }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(categorie.emoji)
                        .accessibilityHidden(true)
                    Text(categorie.libelle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.text)
                    Spacer(minLength: 0)
                    if retenue {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(palette.primary)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                Text(categorie.description)
                    .font(.caption)
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(tailleTexte.isAccessibilitySize ? 6 : 2, reservesSpace: !tailleTexte.isAccessibilitySize)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(retenue ? palette.primaryLight : palette.surface, in: forme)
            .overlay {
                forme.strokeBorder(
                    retenue ? palette.primary : (categorie.carnet ? palette.accent : palette.border),
                    lineWidth: retenue || categorie.carnet ? 1.5 : 1)
            }
            .contentShape(forme)
        }
        .buttonStyle(StyleCarte())
        .accessibilityLabel("\(categorie.libelle) — \(categorie.description)")
        .accessibilityAddTraits(retenue ? [.isSelected] : [])
        .accessibilityIdentifier("nouvelle.categorie.\(categorie.code)")
    }

    private var forme: RoundedRectangle { RoundedRectangle(cornerRadius: Mise.rayon - 2, style: .continuous) }
}
