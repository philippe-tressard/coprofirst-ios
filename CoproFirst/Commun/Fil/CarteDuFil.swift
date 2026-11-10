// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Un élément du fil : l'icône de sa nature dans sa teinte, le titre, une ligne.
/// Une urgence porte le liseré rouge à gauche, comme une affaire urgente ; une affaire
/// datée, sa vignette d'échéance sous le classement (`VignetteEcheance`, #75).
struct CarteDuFil: View {
    let element: ElementDuFil
    @Environment(\.palette) private var palette
    @ScaledMetric(relativeTo: .body) private var cote: CGFloat = 36

    var body: some View {
        let nature = element.nature
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: Pictogrammes.symbole(nature.icone))
                .font(.body.weight(.semibold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(palette[keyPath: nature.couleur])
                .frame(width: cote, height: cote)
                .background(palette[keyPath: nature.fond], in: .rect(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                // Rubrique, heure, puis nature : sur une ligne tant qu'elle tient, sinon l'une sous
                // l'autre (très grand texte) — un libellé ne se coupe jamais (#57).
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { enTete(nature) }.fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: 2) { enTete(nature) }
                }
                // Une affaire datée dit quand elle a lieu, sous son classement (#75).
                if let echeance = element.echeance {
                    VignetteEcheance(echeance: echeance, teinte: palette[keyPath: nature.couleur])
                }
                Text(element.titre)
                    .font(.headline)
                    .foregroundStyle(palette.text)
                if let detail = element.detail.map(TexteDuSite.apercu), !detail.isEmpty {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(palette.textMuted)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            // Une carte du fil s'ouvre TOUJOURS : le chevron le dit.
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.textMuted)
                .frame(maxHeight: .infinity)
                .accessibilityHidden(true)
        }
        .padding(14)
        .padding(.leading, element.urgent ? 4 : 0)
        .background(palette.surface)
        .overlay(alignment: .leading) {
            if element.urgent { palette.danger.frame(width: 4) }
        }
        .clipShape(.rect(cornerRadius: Mise.rayon, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous).strokeBorder(palette.border, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(libelleVocal(nature))
    }

    @ViewBuilder
    private func enTete(_ nature: NatureDuFil) -> some View {
        Text(element.urgent ? "Urgent" : nature.libelle)
            .font(.caption.weight(.bold))
            .foregroundStyle(element.urgent ? palette.danger : palette[keyPath: nature.couleur])
        Text(FormatsDuSite.heure(element.date))
            .font(.caption.monospacedDigit())
            .foregroundStyle(palette.textMuted)
        if let classe = element.natureEnPastille { PastilleNature(nature: classe) }
    }

    private func libelleVocal(_ nature: NatureDuFil) -> Text {
        var morceaux = [element.urgent ? "Urgent" : nature.libelle, element.titre]
        if let classe = element.natureEnPastille { morceaux.append(classe.libelle) }
        morceaux.append(FormatsDuSite.heure(element.date))
        if let echeance = element.echeance { morceaux.append(echeance.enClair) }
        if let detail = element.detail { morceaux.append(TexteDuSite.apercu(detail)) }
        return Text(morceaux.joined(separator: ", "))
    }
}
