// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Un élément du fil : l'icône de sa nature dans sa teinte, le titre, une ligne.
/// Une urgence porte le liseré rouge à gauche, comme une affaire urgente.
struct CarteDuFil: View {
    let element: ElementDuFil
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var tailleTexte
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
                let enTete =
                    tailleTexte.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                    : AnyLayout(HStackLayout(spacing: 6))
                enTete {
                    Text(element.urgent ? "Urgent" : nature.libelle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(element.urgent ? palette.danger : palette[keyPath: nature.couleur])
                    Text(element.date, format: .dateTime.hour().minute())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(palette.textMuted)
                }
                Text(element.titre)
                    .font(.headline)
                    .foregroundStyle(palette.text)
                if let detail = element.detail, !detail.isEmpty {
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

    private func libelleVocal(_ nature: NatureDuFil) -> Text {
        var morceaux = [element.urgent ? "Urgent" : nature.libelle, element.titre]
        morceaux.append(element.date.formatted(.dateTime.hour().minute()))
        if let detail = element.detail { morceaux.append(detail) }
        return Text(morceaux.joined(separator: ", "))
    }
}
