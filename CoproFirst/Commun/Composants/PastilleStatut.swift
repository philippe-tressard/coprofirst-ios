// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le statut d'une affaire, en pastille : le libellé que le serveur SERT
/// (`statut_libelle`, #105), dans la teinte du site (`StatutsAffaire`, généré depuis
/// tickets.ts ; la classe `badge-*` y désigne la couleur d'état de la charte — une
/// teinte, pas une règle). Le cas particulier de `PastilleTeinte`.
struct PastilleStatut: View {
    let statut: String
    let libelle: String

    var body: some View {
        PastilleTeinte(libelle: libelle, badge: StatutsAffaire.pastilles[statut] ?? "badge-gray")
            .accessibilityLabel(Text("Statut : \(libelle)"))
    }
}
