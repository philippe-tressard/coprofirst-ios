// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import UIKit
import UserNotifications

/// Le délégué de l'app, pour ce que SwiftUI ne sert pas : le jeton d'APNs, et la
/// notification touchée — y compris celle qui lance l'app à froid (le délégué du centre
/// est posé dès `didFinishLaunching`, avant que la notification soit remise).
final class DelegueApp: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let push = Lancement.push(ProcessInfo.processInfo.arguments)

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken jeton: Data) {
        Task { await push.jetonRecu(jeton) }
    }

    /// Sans jeton (simulateur sans APNs, réseau), rien : la cloche reste (spec push N9).
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError erreur: Error) {}

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let abonnement = notification.request.content.userInfo[Self.cleAbonnement] as? String
        return await push.presentation(abonnement: abonnement)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive reponse: UNNotificationResponse
    ) async {
        let abonnement = reponse.notification.request.content.userInfo[Self.cleAbonnement] as? String
        await push.touchee(abonnement: abonnement)
    }

    /// La seule clé de la charge que lit l'app, hors `aps` : l'abonnement (spec push §5).
    nonisolated static let cleAbonnement = "a"
}
