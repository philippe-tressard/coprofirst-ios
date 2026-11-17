// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'écran de hall, avant son appairage : le nom, ce que l'écran est, ce qu'il fera.
/// Lu de loin (trois mètres et plus) : les styles de texte de tvOS, déjà à cette échelle.
struct EcranDeHallView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: Mise.marge) {
            Text(EcranDeHall.titre)
                .font(.titre(.largeTitle))
                .foregroundStyle(palette.text)
                .accessibilityIdentifier("hall.titre")
            Text(EcranDeHall.sousTitre)
                .styleLibelle()
            Text(EcranDeHall.attente)
                .font(.title3)
                .foregroundStyle(palette.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: MiseTV.mesure)
                .accessibilityIdentifier("hall.attente")
        }
        .padding(Mise.marge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg)
    }
}
