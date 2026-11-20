// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import WatchKit

/// Le délégué de l'app montre, pour ce que SwiftUI ne sert pas : le rafraîchissement
/// d'ARRIÈRE-PLAN (#226, lot 3). Toutes les `intervalle` secondes au mieux (watchOS en décide),
/// la cloche se relit, la garde hors ligne et le widget avec elle — comme la tuile de Wear OS,
/// que le système redemande toutes les 15 minutes. La liaison est créée ici, au lancement : un
/// message de l'iPhone arrivé app fermée est remis dès qu'elle écoute.
@MainActor
final class DelegueMontre: NSObject, WKApplicationDelegate {
    let liaison = LiaisonDeLaMontre.auLancement(ProcessInfo.processInfo.arguments)

    /// 30 minutes : watchOS borne les rafraîchissements d'une app (quatre par heure au plus,
    /// moins si elle n'est pas sur le cadran).
    static let intervalle: TimeInterval = 30 * 60

    func applicationDidFinishLaunching() {
        Self.planifier()
    }

    func handle(_ taches: Set<WKRefreshBackgroundTask>) {
        for tache in taches {
            guard let rafraichissement = tache as? WKApplicationRefreshBackgroundTask else {
                tache.setTaskCompletedWithSnapshot(false)
                continue
            }
            Task {
                await liaison.rafraichir()
                Self.planifier()
                rafraichissement.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    /// Le prochain rafraîchissement ; un refus de watchOS ne se dit pas — l'ouverture de l'app
    /// relit de toute façon.
    static func planifier() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date(timeIntervalSinceNow: intervalle), userInfo: nil
        ) { _ in }
    }
}
