// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'encart d'avertissement du site (`EncartAvertissement.svelte`) : le fond, la bordure et
/// le rayon de la teinte « warning », une seule écriture — l'alerte du carnet, la
/// confirmation d'une adresse, l'installation suspendue sur la page de connexion.
private struct EncartAvertissement: ViewModifier {
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.warningFond, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                    .strokeBorder(palette.warningBordure, lineWidth: 1)
            }
    }
}

extension View {
    /// Dans l'encart d'avertissement du site, pleine largeur.
    func encartAvertissement() -> some View { modifier(EncartAvertissement()) }
}
