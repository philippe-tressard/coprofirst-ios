// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Une alerte de la cloche : le point des non lues (celui de l'iPhone), le titre sur deux
/// lignes au plus, l'âge relatif, et « Urgent » à la couleur de danger de la charte. Un
/// toucher ouvre le détail.
struct LigneAlerte: View {
    let alerte: NotificationRecue
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationLink(value: alerte) {
            HStack(alignment: .firstTextBaseline, spacing: MiseMontre.espace) {
                Circle()
                    .fill(alerte.lue ? Color.clear : palette.primary)
                    .frame(width: MiseMontre.point, height: MiseMontre.point)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: MiseMontre.interligne) {
                    Text(alerte.titre)
                        .font(.headline.weight(alerte.lue ? .regular : .semibold))
                        .lineLimit(2)
                    if alerte.urgente {
                        MarqueUrgente()
                    }
                    Text(FormatsDuSite.relatif(alerte.creeLe))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        // Le lien réunit déjà son contenu en UN bouton : le titre, la marque et l'âge.
        .accessibilityValue(alerte.lue ? "" : TextesMontre.nonLue)
        .accessibilityIdentifier("montre.alerte.\(alerte.id)")
    }
}

/// « Urgent », à la couleur de danger de la charte — la marque de la cloche de l'iPhone.
struct MarqueUrgente: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Text(TextesNotifications.urgent)
            .font(.footnote.weight(.bold))
            .foregroundStyle(palette.danger)
    }
}
