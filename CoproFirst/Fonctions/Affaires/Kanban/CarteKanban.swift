// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Une affaire au Kanban : son prestataire, son titre, sa catégorie et son numéro —
/// la carte du site (`VueKanbanAffaires`), sans l'aperçu : la colonne dit l'état.
struct CarteKanban: View {
    let affaire: Affaire
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let prestataire = affaire.prestataire {
                Text(prestataire)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.textMuted)
            }
            Text(affaire.titre)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.text)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(pied)
                .font(.caption)
                .foregroundStyle(palette.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(palette.surface, in: .rect(cornerRadius: Mise.rayon - 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Mise.rayon - 4, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            if affaire.urgente {
                UnevenRoundedRectangle(
                    topLeadingRadius: Mise.rayon - 4, bottomLeadingRadius: Mise.rayon - 4, style: .continuous
                )
                .fill(palette.danger)
                .frame(width: 4)
                .accessibilityHidden(true)
            }
        }
        .contentShape(.rect(cornerRadius: Mise.rayon - 4))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                [affaire.urgente ? "Urgente" : nil, affaire.titre, affaire.prestataire, pied]
                    .compactMap { $0 }.joined(separator: ", ")))
    }

    /// « 🛠️ Panne · A-0041 » — la catégorie et le numéro, comme le pied de carte du site.
    private var pied: String {
        let categorie = TablesDuSite.categorieParCode[affaire.categorie].map { "\($0.emoji) \($0.libelle)" }
        return [categorie, affaire.numero].compactMap { $0 }.joined(separator: " · ")
    }
}
