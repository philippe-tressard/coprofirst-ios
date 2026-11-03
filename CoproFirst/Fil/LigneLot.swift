// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// En haut à gauche du fil, sous son titre : le logement de l'utilisateur, sur une
/// ligne — comme l'en-tête de l'accueil du site. Un toucher ouvre l'onglet Accès.
/// Sans libellé servi (utilisateur sans lot, ou API qui ne le sert pas) : rien.
///
/// Pas dans la barre de navigation : à côté de la pastille de la résidence et de la
/// cloche, elle la faisait déborder, et iOS repliait la pastille dans un menu « … ».
struct LigneLot: View {
    let profil: ProfilResidence?
    let ouvrir: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        if let logement = profil?.libelleLogement, !logement.isEmpty {
            Button(action: ouvrir) {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(palette.primary)
                        .accessibilityHidden(true)
                    Text(logement)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.textMuted)
                        .accessibilityHidden(true)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(palette.text)
                .frame(minHeight: Mise.cible, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Mise.marge)
            .accessibilityLabel(Text("Mon logement : \(logement)"))
            .accessibilityHint("Ouvre Mes lots & accès")
            .accessibilityIdentifier("fil.lot")
        }
    }
}
