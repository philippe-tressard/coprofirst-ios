// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// L'appairage gardé d'un lancement à l'autre (#218, lot 3) : la résidence et le jeton de
/// l'écran, au Trousseau de l'appareil (`CoffreTrousseau`, jamais synchronisé), jamais dans
/// les réglages. Rallumée, l'Apple TV reprend la diffusion sans personne devant elle.
struct MemoireEcran {
    /// Ce que l'écran garde : où il lit, et avec quoi.
    struct Appairage: Codable, Equatable, Sendable {
        let residence: Installation
        let jeton: String
    }

    private static let cle = "ecran-de-hall"
    let coffre: any CoffreDuCompte

    func lire() -> Appairage? {
        coffre.lire(Self.cle).flatMap { try? JSONDecoder().decode(Appairage.self, from: $0) }
    }

    /// `false` : le Trousseau a refusé (un build sans signature) — l'écran diffuse quand même,
    /// il redemandera un appairage au prochain lancement.
    @discardableResult
    func ranger(_ appairage: Appairage) -> Bool {
        guard let donnees = try? JSONEncoder().encode(appairage) else { return false }
        return coffre.ranger(donnees, Self.cle)
    }

    func oublier() { coffre.effacer(Self.cle) }
}
