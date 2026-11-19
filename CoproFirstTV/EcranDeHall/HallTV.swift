// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Observation

/// Où en est l'écran de hall (#218) : l'entrée (lot 2), l'appairage, puis la diffusion
/// (lot 3). L'étape se DÉDUIT de deux faits — une résidence reconnue, un appairage gardé —
/// et ne se range nulle part ailleurs.
@MainActor @Observable
final class HallTV {
    enum Etape: Equatable {
        case entree
        case appairage(Installation)
        case diffusion(MemoireEcran.Appairage)
    }

    let entree: EntreeTV
    let service: any ServiceEcranTV
    private let memoire: MemoireEcran
    private(set) var appaire: MemoireEcran.Appairage?

    init(entree: EntreeTV = EntreeTV(), service: any ServiceEcranTV = ServiceEcranAPI(), memoire: MemoireEcran) {
        self.entree = entree
        self.service = service
        self.memoire = memoire
        appaire = memoire.lire()
    }

    var etape: Etape {
        if let appaire { return .diffusion(appaire) }
        if let residence = entree.residence { return .appairage(residence) }
        return .entree
    }

    /// La palette de ce que l'écran montre : celle de la résidence dès qu'il y en a une.
    var residence: Installation? { appaire?.residence ?? entree.residence }

    /// Le conseil a confirmé : l'écran garde son accès et diffuse.
    func appairer(_ residence: Installation, jeton: String) {
        let appairage = MemoireEcran.Appairage(residence: residence, jeton: jeton)
        memoire.ranger(appairage)
        appaire = appairage
    }

    /// Le serveur ne reconnaît plus le jeton : l'écran oublie son accès et affiche un nouveau
    /// code, pour la même résidence.
    func retirer() {
        guard let appaire else { return }
        memoire.oublier()
        entree.reprendre(appaire.residence)
        self.appaire = nil
    }
}
