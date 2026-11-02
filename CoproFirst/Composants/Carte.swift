// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La surface d'une carte : blanche au clair, un cran au-dessus du fond au sombre.
/// Ni ombre ni dégradé : le filet de la charte suffit à la détacher.
struct Carte<Contenu: View>: View {
    @Environment(\.palette) private var palette
    @ViewBuilder let contenu: () -> Contenu

    var body: some View {
        contenu()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(palette.surface, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                    .strokeBorder(palette.border, lineWidth: 1)
            }
    }
}
