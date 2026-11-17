// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La page retenue (`Parcours.onglet`) des présentations qui montrent TOUTES les pages : le
/// détail de la barre latérale (#221) et la page du carnet (#119). Chacune a SA pile :
/// changer de page repart de son écran. Un onglet qui n'est plus offert (un rôle retiré,
/// « Plus » d'avant une rotation) : la première page, le fil.
struct PageRetenue: View {
    let pages: [PageDeNavigation]
    let installation: Installation
    @Environment(Parcours.self) private var parcours

    var body: some View {
        if let fixe = EntreeFixe(rawValue: parcours.onglet) {
            NavigationStack {
                fixe.ecran(installation)
                    .toolbar { PastilleOuSuisJe(installation: installation, cloche: true) }
            }
            .id(fixe.id)
        } else if let page = pages.first(where: { $0.id == parcours.onglet }) ?? pages.first {
            // La page, et la colonne où ses listes ouvrent leurs fiches (`ListeEtFiche`, #222).
            PageEtColonneDeFiche { EcranDePage(page: page, installation: installation) }
                .id(page.id)
        }
    }
}
