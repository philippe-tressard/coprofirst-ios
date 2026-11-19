// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'app Apple TV : l'écran de hall d'une résidence (#218), et rien d'autre. Elle ne fait
/// que lire — aucune saisie après l'adresse, aucun compte de personne : appairée par le
/// conseil syndical (#295), elle fait défiler les annonces de hall de son périmètre.
///
/// Elle compile les MÊMES fichiers que l'app iPhone pour la charte et les formats du site
/// (`project.yml`, cible `CoproFirstTV`) : jamais une copie.
@main
struct CoproFirstTVApp: App {
    @State private var hall = HallTV(memoire: MemoireEcran(coffre: CoffreTrousseau()))

    var body: some Scene {
        WindowGroup {
            EcranDeHallView(hall: hall)
        }
    }
}
