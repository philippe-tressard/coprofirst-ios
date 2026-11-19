// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Une alerte reçue, telle que GET /notifications la sert (`NotificationRead`).
struct NotificationRecue: Hashable, Sendable, Identifiable, Codable {
    let id: Int
    let type: String
    let titre: String
    /// Du HTML de l'éditeur : il passe par `TexteDuSite`.
    let corps: String
    var lue: Bool
    let urgente: Bool
    let creeLe: Date
}

extension NotificationRecue {
    init(lue notification: Components.Schemas.NotificationRead) {
        self.init(
            id: notification.id, type: notification._type, titre: notification.titre, corps: notification.corps,
            lue: notification.lue, urgente: notification.urgente, creeLe: notification.creeLe)
    }
}
