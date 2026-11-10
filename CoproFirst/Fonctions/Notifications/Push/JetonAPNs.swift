// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Le jeton d'appareil qu'APNs donne à l'app : un identifiant d'une personne (spec push
/// N8). Il ne part que dans le corps de POST /appareils, et ne s'écrit JAMAIS — ni dans
/// un journal, ni sur le disque, ni dans un message d'erreur : sa description, son
/// reflet et son `dump` sont masqués. iOS le redonne à chaque inscription.
struct JetonAPNs: Hashable, Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    /// Les octets d'APNs, en hexadécimal minuscule (`AppareilEnregistre.jeton`).
    let hexadecimal: String

    init(_ octets: Data) {
        hexadecimal = octets.map { String(format: "%02x", $0) }.joined()
    }

    static let masque = "‹jeton APNs masqué›"
    var description: String { Self.masque }
    var debugDescription: String { Self.masque }
    var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}
