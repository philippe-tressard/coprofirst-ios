// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Observation

/// L'état de « Annuaire CS & Syndic » : les deux fiches lues, et leurs gestes. Chaque
/// geste réécrit la fiche ENTIÈRE (`PUT`), qui rend la composition ENREGISTRÉE — les
/// fiches neuves y reçoivent leur numéro, les noms leur rapprochement : l'écran montre
/// ce que le serveur a retenu, pas ce qu'on lui a envoyé (#55).
@MainActor
@Observable
final class EtatAnnuaireCS {
    enum Lecture<Valeur: Equatable & Sendable>: Equatable, Sendable {
        case chargement
        case pret(Valeur)
        case erreur(String)

        var valeur: Valeur? { if case .pret(let valeur) = self { valeur } else { nil } }
    }

    private(set) var conseil = Lecture<ConseilCS>.chargement
    private(set) var syndic = Lecture<SyndicCS>.chargement

    func charger(_ service: any ServiceAnnuaireCS, _ installation: Installation) async {
        async let conseil = Self.lire { try await service.conseil(installation) }
        async let syndic = Self.lire { try await service.syndic(installation) }
        let (lusConseil, lusSyndic) = await (conseil, syndic)
        // Une relecture qui échoue garde ce qui est affiché.
        if lusConseil.valeur != nil || self.conseil.valeur == nil { self.conseil = lusConseil }
        if lusSyndic.valeur != nil || self.syndic.valeur == nil { self.syndic = lusSyndic }
    }

    func enregistrer(
        _ nouveau: ConseilCS, _ service: any ServiceAnnuaireCS, _ installation: Installation
    ) async throws {
        conseil = .pret(try await service.enregistrer(nouveau, dans: installation))
    }

    func enregistrer(
        _ nouveau: SyndicCS, _ service: any ServiceAnnuaireCS, _ installation: Installation
    ) async throws {
        syndic = .pret(try await service.enregistrer(nouveau, dans: installation))
    }

    private static func lire<V: Equatable & Sendable>(_ lecture: () async throws -> V) async -> Lecture<V> {
        do {
            return .pret(try await lecture())
        } catch {
            return .erreur(ErreurService.phrase(error, sinon: TextesAnnuaireCS.erreurChargement))
        }
    }
}

extension ConseilCS {
    /// Désigne le président — un seul : le choix en retire l'ancien (`surPresident`).
    func avecPresident(_ rang: Int?) -> ConseilCS {
        var copie = self
        for i in copie.membres.indices { copie.membres[i].estPresident = i == rang }
        return copie
    }
}

extension SyndicCS {
    /// Désigne l'interlocuteur principal — un seul (`designer`).
    func avecPrincipal(_ rang: Int?) -> SyndicCS {
        var copie = self
        for i in copie.membres.indices { copie.membres[i].estPrincipal = i == rang }
        return copie
    }

    /// Monte ou descend un interlocuteur : l'ordre compte, il est celui de l'annuaire.
    func deplace(_ rang: Int, de sens: Int) -> SyndicCS {
        var copie = self
        let cible = rang + sens
        guard copie.membres.indices.contains(rang), copie.membres.indices.contains(cible) else { return self }
        copie.membres.swapAt(rang, cible)
        return copie
    }
}
