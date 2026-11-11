// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import UIKit
import UserNotifications

/// Où en est l'autorisation des notifications, côté iOS.
enum AutorisationPush: Equatable, Sendable {
    /// Pas encore lue (au lancement, avant la première lecture).
    case inconnue
    /// Jamais demandée : l'app peut la proposer — au bon moment, jamais à froid.
    case nonDemandee
    case accordee
    /// Refusée : seuls les Réglages d'iOS la rendent ; l'app ne la redemande pas.
    case refusee
}

/// Ce que l'app demande au système pour les notifications : deux réalisations, celle
/// d'iOS et une simulée (`-api-simulee`), où aucune alerte système ne s'ouvre.
protocol CentreNotifications: Sendable {
    func autorisation() async -> AutorisationPush
    /// L'alerte système. Ni pastille (§10, décision 3 : aucun nombre chez Apple) ni
    /// options provisoires : bannière et son, rien d'autre.
    func demander() async -> Bool
    /// Demande à iOS le jeton d'appareil ; il arrive par le délégué de l'app.
    @MainActor func inscrire()
}

/// Le centre d'iOS.
struct CentreSysteme: CentreNotifications {
    func autorisation() async -> AutorisationPush {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .nonDemandee
        case .denied: .refusee
        default: .accordee
        }
    }

    func demander() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    @MainActor func inscrire() {
        UIApplication.shared.registerForRemoteNotifications()
    }
}

#if DEBUG
/// Le centre simulé : l'autorisation est celle du lancement (`-push non-demandee|refusee`,
/// accordée sinon), « Autoriser » est répondu d'office, et l'inscription rend un
/// jeton inventé, par le même chemin que celui d'iOS.
final class CentreSimule: CentreNotifications, @unchecked Sendable {
    private var etat: AutorisationPush
    private var demandesFaites = 0
    private let verrou = NSLock()
    /// Ce que fait l'app du jeton reçu — `NotificationsPush.jetonRecu`.
    @MainActor var jetonRecu: ((Data) -> Void)?
    /// Les inscriptions demandées, pour les tests.
    @MainActor private(set) var inscriptions = 0

    /// 32 octets inventés : la taille d'un jeton d'APNs.
    static let jeton = Data((0..<32).map { UInt8($0 * 7 % 256) })

    init(_ etat: AutorisationPush = .nonDemandee) {
        self.etat = etat
    }

    func autorisation() async -> AutorisationPush { verrou.withLock { etat } }

    /// Les alertes système ouvertes — aucune sans un geste de l'utilisateur.
    var demandes: Int { verrou.withLock { demandesFaites } }

    func demander() async -> Bool {
        verrou.withLock {
            demandesFaites += 1
            if etat == .nonDemandee { etat = .accordee }
            return etat == .accordee
        }
    }

    @MainActor func inscrire() {
        inscriptions += 1
        jetonRecu?(Self.jeton)
    }
}
#endif
