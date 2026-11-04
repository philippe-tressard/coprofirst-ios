// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le statut d'une affaire, en pastille : le libellé et la teinte du site
/// (`StatutsAffaire`, généré depuis tickets.ts ; la classe `badge-*` y désigne la
/// couleur d'état de la charte). Le cas particulier de `PastilleTeinte`.
struct PastilleStatut: View {
    let statut: String

    var body: some View {
        let (libelle, pastille) = StatutsAffaire.parCode[statut] ?? (statut, "badge-gray")
        PastilleTeinte(libelle: libelle, badge: pastille)
            .accessibilityLabel(Text("Statut : \(libelle)"))
    }
}
