// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le détail d'une alerte : son titre, « Urgent » s'il y a lieu, sa date et son corps en
/// entier, lu par le lecteur du texte du site — celui de la cloche de l'iPhone. L'ouvrir ne
/// la marque pas comme lue (jeton en lecture seule, #226).
struct AlerteView: View {
    let alerte: NotificationRecue
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MiseMontre.espace) {
                Text(alerte.titre)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                if alerte.urgente {
                    MarqueUrgente()
                }
                Text(FormatsDuSite.dateHeure(alerte.creeLe))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !TexteDuSite.apercu(alerte.corps).isEmpty {
                    Text(TexteDuSite.riche(alerte.corps))
                        .tint(palette.primary)
                        .accessibilityIdentifier("montre.corps")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("montre.detail.\(alerte.id)")
    }
}
