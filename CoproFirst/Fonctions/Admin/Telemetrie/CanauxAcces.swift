// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le bloc « Accès : site ou application » (`CanauxAcces.svelte`, coprofirst#2726) : une
/// ligne par canal qui a des vues — son libellé, ses vues et sa part, ses utilisateurs —,
/// la part en jauge. Tout est servi : rien ne se recalcule ici.
struct CanauxAcces: View {
    let canaux: [PartCanal]
    @Environment(\.palette) private var palette

    /// La colonne « Utilisateurs » du site : seulement si un canal en sert (Jour, Mois).
    private var avecUtilisateurs: Bool { canaux.contains { $0.visiteurs != nil } }

    var body: some View {
        Carte {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(canaux.enumerated()), id: \.element.id) { rang, canal in
                    if rang > 0 { Divider().overlay(palette.border) }
                    ligne(canal).padding(.vertical, 8)
                }
                if let pied = TextesTelemetrie.piedAcces(canaux) {
                    Text(pied)
                        .font(.footnote)
                        .foregroundStyle(palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }
            }
        }
        // Pas d'identifiant sur la carte : posé sur un conteneur, SwiftUI le donne à chaque
        // ligne, et celui de chaque canal (`admin.telemetrie.acces.<canal>`) se perdrait.
    }

    private func ligne(_ canal: PartCanal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(TextesTelemetrie.vuesEtPart(canal)).monospacedDigit().foregroundStyle(palette.text)
                    if avecUtilisateurs {
                        Text(TextesTelemetrie.utilisateurs(canal))
                            .font(.footnote).monospacedDigit().foregroundStyle(palette.textMuted)
                    }
                }
            } label: {
                Text(canal.libelle).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
            }
            ProgressView(value: Double(min(max(canal.part, 0), 100)), total: 100)
                .tint(palette.primary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("admin.telemetrie.acces.\(canal.canal)")
    }
}
