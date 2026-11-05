// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Un intertitre de section, avec son compte (« 🏢 Lots possédés (3) »).
struct Intertitre: View {
    let titre: String
    var compte: Int?
    @Environment(\.palette) private var palette

    var body: some View {
        Text(compte.map { "\(titre) (\($0))" } ?? titre)
            .font(.titre(.title3))
            .foregroundStyle(palette.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Une ligne « libellé — valeur » d'une fiche (le `<dl>` du site). En très grand
/// texte, la valeur passe sous le libellé.
struct LigneFiche: View {
    let libelle: String
    let valeur: String
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var taille

    var body: some View {
        let disposition =
            taille.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        disposition {
            Text(libelle)
                .font(.subheadline)
                .foregroundStyle(palette.textMuted)
                .frame(minWidth: taille.isAccessibilitySize ? nil : 110, alignment: .leading)
            Text(valeur)
                .font(.body)
                .foregroundStyle(palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Un état vide ou une note, dans une carte : un titre facultatif et son texte.
struct NoteAcces: View {
    var titre: String?
    let texte: String
    var pictogramme = "info.circle"
    @Environment(\.palette) private var palette

    var body: some View {
        Carte {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: pictogramme)
                    .foregroundStyle(palette.textMuted)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    if let titre {
                        Text(titre).font(.headline).foregroundStyle(palette.text)
                    }
                    Text(texte).font(.subheadline).foregroundStyle(palette.textMuted)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
