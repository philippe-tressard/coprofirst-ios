// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import WatchKit

/// L'app Apple Watch (#226) : la cloche de la dernière résidence ouverte sur l'iPhone, en
/// LECTURE seule — rien ne s'y marque comme lu (décision de Philippe, 16/11/2026), rien ne
/// s'y saisit. Le reste de CoproFirst (fil, affaires, communauté…) reste à l'iPhone.
///
/// Elle compile les MÊMES fichiers que l'app iPhone pour la charte, les formats du site et
/// l'alerte servie (`project.yml`, cible `CoproFirstWatch`) : jamais une copie.
@main
struct CoproFirstWatchApp: App {
    /// La liaison et le rafraîchissement d'arrière-plan (#226, lot 3).
    @WKApplicationDelegateAdaptor(DelegueMontre.self) private var delegue

    var body: some Scene {
        WindowGroup {
            RacineMontre(liaison: delegue.liaison)
        }
    }
}
