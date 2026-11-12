// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Hors ligne : dit une fois, en haut, tant que ça dure — jamais une alerte.
///
/// Le bandeau décide seul de paraître (un écran le pose sans condition) :
/// - la résidence est ouverte SANS réseau, sur sa dernière lecture gardée (#101) : il dit
///   d'où viennent les données (« à jour au… ») et pourquoi les gestes sont grisés ;
/// - l'appareil perd le réseau, l'app ouverte : ce qui est affiché peut dater.
struct BandeauHorsLigne: View {
    /// Le toit sans onde : symbole du catalogue, généré par
    /// `scripts/rendre-symbole-hors-ligne.swift` ; il suit la taille du libellé.
    static let pictogramme = "hors-ligne"
    static let identifiant = "horsligne.bandeau"
    @Environment(\.palette) private var palette
    @Environment(Parcours.self) private var parcours: Parcours?
    @Environment(Reseau.self) private var reseau: Reseau?

    var body: some View {
        if let consultation = parcours?.consultation {
            bandeau(consultation.phrase, precision: TextesHorsLigne.consultationSeule)
        } else if reseau?.enLigne == false {
            bandeau(TextesHorsLigne.peutDater, precision: nil)
        }
    }

    private func bandeau(_ phrase: String, precision: String?) -> some View {
        VStack(spacing: 2) {
            Label(phrase, image: Self.pictogramme)
                .font(.footnote.weight(.medium))
                .foregroundStyle(palette.text)
            if let precision {
                Text(precision)
                    .font(.caption)
                    .foregroundStyle(palette.textMuted)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, Mise.marge)
        .background(.bar)
        // Une seule annonce pour VoiceOver : la phrase, puis sa précision.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(Self.identifiant)
    }
}
