// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Premier écran : le nom du produit, en attendant la vitrine (coprofirst-site#42).
///
/// Couleurs système seulement : celles de CoproFirst se généreront depuis ses
/// sources, jamais recopiées (CLAUDE.md).
struct AccueilView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text(Accueil.titre)
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("accueil.titre")
            Text(Accueil.accroche)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Les textes de l'écran d'accueil, écrits une fois : la vue et les tests les lisent ici.
enum Accueil {
    static let titre = "CoproFirst"
    static let accroche = "Le logiciel libre de gestion de copropriété."
}

#Preview {
    AccueilView()
}
