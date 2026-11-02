// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Observation
import SwiftUI

/// Où en est l'utilisateur : la pile de navigation avant connexion, puis la
/// résidence ouverte. Une seule source, lue par la racine.
@MainActor @Observable
final class Parcours {
    enum Etape: Hashable {
        case residence
        case connexion(Installation)
    }

    var chemin: [Etape] = []
    private(set) var ouverte: Installation?
    let service: any ServiceCoproFirst
    let connues: InstallationsConnues

    init(service: any ServiceCoproFirst, connues: InstallationsConnues, ouverte: Installation? = nil) {
        self.service = service
        self.connues = connues
        self.ouverte = ouverte
    }

    func ouvrir(_ installation: Installation) {
        connues.retenir(installation)
        ouverte = installation
        chemin = []
    }

    func quitter() {
        ouverte = nil
    }
}
