// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Network
import Observation

/// L'appareil est-il en ligne ? Un seul observateur pour toute l'app.
@MainActor @Observable
final class Reseau {
    private(set) var enLigne = true
    private let moniteur = NWPathMonitor()

    /// `fige` : un état qui ne change pas — l'appareil sans réseau des tests d'interface
    /// (`-hors-ligne`, Debug seul) ; `nil` : l'observateur du système.
    init(fige: Bool? = nil) {
        if let fige {
            enLigne = fige
            return
        }
        moniteur.pathUpdateHandler = { [weak self] chemin in
            let enLigne = chemin.status == .satisfied
            Task { @MainActor in self?.enLigne = enLigne }
        }
        moniteur.start(queue: .global(qos: .utility))
    }
}
