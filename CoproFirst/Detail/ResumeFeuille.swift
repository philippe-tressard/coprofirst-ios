// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Un élément sans écran natif — ou sans page sur le site : son résumé, jamais rien.
struct ResumeFeuille: View {
    let element: ElementDuFil
    let installation: Installation
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var ouvrirLien

    var body: some View {
        let nature = element.nature
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: Pictogrammes.symbole(nature.icone))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette[keyPath: nature.couleur])
                        .frame(width: 36, height: 36)
                        .background(palette[keyPath: nature.fond], in: .rect(cornerRadius: 10, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(nature.libelle).font(.caption.weight(.bold)).foregroundStyle(
                            palette[keyPath: nature.couleur])
                        Text(element.date, format: .dateTime.weekday(.wide).day().month(.wide).hour().minute())
                            .font(.caption)
                            .foregroundStyle(palette.textMuted)
                    }
                }
                Text(element.titre)
                    .font(.titre(.title2))
                    .foregroundStyle(palette.text)
                    .accessibilityAddTraits(.isHeader)
                if let detail = element.detail, !detail.isEmpty {
                    Text(detail).font(.body).foregroundStyle(palette.text).textSelection(.enabled)
                }
                if case .resume(let lien?) = element.cible,
                    let page = URL(string: lien, relativeTo: installation.adresse)?.absoluteURL,
                    page.host() == installation.adresse.host()
                {
                    Button {
                        ouvrirLien(page)
                    } label: {
                        Label("Voir sur le site", systemImage: "safari")
                    }
                    .buttonStyle(.clair)
                    .padding(.top, 6)
                }
            }
            .padding(Mise.marge)
        }
        .background(palette.bg)
        .accessibilityIdentifier("resume")
    }
}
