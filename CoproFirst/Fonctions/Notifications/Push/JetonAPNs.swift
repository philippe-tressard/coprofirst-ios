// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Le jeton d'appareil qu'APNs donne à l'app : un identifiant d'une personne (spec push
/// N8). Il ne part que dans le corps de POST /appareils, et ne s'écrit JAMAIS — ni dans
/// un journal, ni sur le disque, ni dans un message d'erreur : gardé dans un `JetonMasque`
/// (#342), sa description, son reflet et son `dump` le taisent. iOS le redonne à chaque
/// inscription.
struct JetonAPNs: Hashable, Sendable {
    /// Les octets d'APNs, en hexadécimal minuscule (`AppareilEnregistre.jeton`).
    let hexadecimal: JetonMasque

    init(_ octets: Data) {
        hexadecimal = JetonMasque(octets.map { String(format: "%02x", $0) }.joined())
    }
}
