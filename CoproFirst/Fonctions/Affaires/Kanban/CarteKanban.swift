// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Une affaire au Kanban : son premier prestataire (« +N » pour les autres), son titre, sa catégorie et son numéro —
/// la carte du site (`VueKanbanAffaires`), sans l'aperçu : la colonne dit l'état.
struct CarteKanban: View {
    let affaire: Affaire
    /// Le pictogramme de sa catégorie, servi (`GET /tickets/referentiels`) ; `nil` s'il manque.
    let emoji: String?
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Le premier prestataire, et combien d'autres : « Ascenseurs du Parc +1 » (#181).
            if let prestataires = TextesPrestatairesAffaire.carte(affaire.prestataires) {
                Text(prestataires)
                    .lineLimit(1)
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
                // VoiceOver lit la liste entière, là où l'œil lit « +N ».
                ([affaire.urgente ? "Urgente" : nil, affaire.titre] + affaire.prestataires + [pied])
                    .compactMap { $0 }.joined(separator: ", ")))
    }

    /// « 🛠️ Panne · A-0041 » — la catégorie et le numéro, comme le pied de carte du site.
    /// Le libellé est celui que le serveur SERT (`categorie_libelle`), jamais vide.
    private var pied: String {
        let categorie = [emoji, affaire.categorieLibelle].compactMap { $0 }.joined(separator: " ")
        return [categorie, affaire.numero].joined(separator: " · ")
    }
}
