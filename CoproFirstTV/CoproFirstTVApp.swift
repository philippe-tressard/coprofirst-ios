// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'app Apple TV : l'écran de hall d'une résidence (#218), et rien d'autre. Elle ne fait
/// que lire — aucune saisie, aucun compte de personne : un écran appairé fera défiler les
/// affiches de son périmètre (appairage et diffusion : lots 3 et 4, après coprofirst#2770).
///
/// Elle compile les MÊMES fichiers que l'app iPhone pour la charte et les formats du site
/// (`project.yml`, cible `CoproFirstTV`) : jamais une copie.
@main
struct CoproFirstTVApp: App {
    var body: some Scene {
        WindowGroup {
            EcranDeHallView()
        }
    }
}
