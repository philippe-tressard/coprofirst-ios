// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La vignette d'échéance d'une carte du fil (#75), sous le classement : le délai servi,
/// à la teinte de la nature (gris une fois passé), puis la ou les dates.
///
/// Au téléphone, la gouttière du site devient une LIGNE (`EcheanceGouttiere.svelte`,
/// `max-width: 480px`) : délai puis dates, côte à côte — ici aussi. Aux tailles
/// d'accessibilité, les dates passent sous le délai. Rien d'animé : le fil se parcourt
/// souvent, la vignette s'y lit, elle ne s'y annonce pas.
struct VignetteEcheance: View {
    let echeance: EcheanceDuFil
    /// La teinte de la nature de la carte (`--nature-fort` du site).
    let teinte: Color
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var tailleTexte

    var body: some View {
        let ligne =
            tailleTexte.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6))
        ligne {
            if let libelle = echeance.libelle {
                Text(libelle)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(echeance.passee ? palette.textMuted : teinte)
            }
            Text(echeance.dates())
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(palette.textMuted)
        }
    }
}
