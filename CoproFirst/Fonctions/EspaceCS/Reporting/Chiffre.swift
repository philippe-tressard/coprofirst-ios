// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Un chiffre du Reporting (`kpi-card`) : la valeur, et ce qu'elle compte ; teinté s'il alerte.
struct Chiffre: View {
    let valeur: Int
    let libelle: String
    var alerte = false
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(FormatsDuSite.nombre(valeur))
                .font(.titre(.title))
                .monospacedDigit()
                .foregroundStyle(alerte ? palette.danger : palette.text)
                .contentTransition(.numericText())
            Text(libelle)
                .font(.footnote)
                .foregroundStyle(palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            alerte ? palette.dangerFond : palette.surface, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                .strokeBorder(alerte ? palette.dangerBordure : palette.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Les chiffres d'un relevé, côte à côte — l'un sous l'autre aux grandes tailles.
struct RangeeDeChiffres<Contenu: View>: View {
    @ViewBuilder let contenu: () -> Contenu
    @Environment(\.dynamicTypeSize) private var taille

    var body: some View {
        let disposition =
            taille.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        disposition { contenu() }
    }
}
