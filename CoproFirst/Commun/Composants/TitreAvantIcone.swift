// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le titre, puis l'icône : « 💡 Synthèse ⌄ » (comme le bouton du site), « Lendemain › ».
/// `policeIcone` règle l'icône seule (un chevron plus discret que le titre) ; absente, elle
/// suit le titre.
struct TitreAvantIcone: LabelStyle {
    var policeIcone: Font?

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            if let policeIcone {
                configuration.icon.font(policeIcone)
            } else {
                configuration.icon
            }
        }
    }
}
