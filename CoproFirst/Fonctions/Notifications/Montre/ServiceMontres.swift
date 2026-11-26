// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Un jeton de montre émis ou renouvelé (`MontreEmise`) : le brut n'est rendu qu'à ce moment,
/// et ne fait que passer — vers la montre, jamais sur le disque de l'iPhone ni dans une trace.
struct JetonDeMontre: Equatable, Sendable {
    let id: Int
    let jeton: JetonMasque
    let expireLe: Date
}

/// Les montres du compte connecté (coprofirst#2771), demandées par l'iPhone SEUL : la montre
/// ne connaît que son jeton (#226).
protocol ServiceMontres: Sendable {
    /// POST /montres : un jeton neuf pour une Apple Watch (au plus 4 montres par compte).
    func emettreMontre(dans installation: Installation) async throws -> JetonDeMontre
    /// POST /montres/{id}/renouveler : un jeton neuf, 30 jours de plus. Une montre que le
    /// serveur ne connaît plus (retirée, échue, purgée) lève `ErreurService.introuvable`.
    func renouvelerMontre(_ id: Int, dans installation: Installation) async throws -> JetonDeMontre
    /// DELETE /montres/{id} : son jeton cesse aussitôt de servir.
    func retirerMontre(_ id: Int, dans installation: Installation) async throws
}

extension ServiceCoproFirst {
    /// Le service des montres ; les deux réalisations s'y conforment
    /// (`LiaisonsMontreTests` le vérifie à la compilation).
    var serviceMontres: (any ServiceMontres)? { self as? any ServiceMontres }
}

extension ServiceAPI: ServiceMontres {
    func emettreMontre(dans installation: Installation) async throws -> JetonDeMontre {
        let sortie = try await appeler {
            try await client(installation.adresse).postMontres(body: .json(.init(plateforme: .watchos)))
        }
        switch sortie {
        case .created(let cree): return try JetonDeMontre(cree.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func renouvelerMontre(_ id: Int, dans installation: Installation) async throws -> JetonDeMontre {
        let sortie = try await appeler {
            try await client(installation.adresse).postMontresMontreIdRenouveler(path: .init(montreId: id))
        }
        switch sortie {
        case .ok(let ok): return try JetonDeMontre(ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(404, _): throw ErreurService.introuvable
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func retirerMontre(_ id: Int, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).deleteMontresMontreId(path: .init(montreId: id))
        }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}

extension JetonDeMontre {
    /// La seule lecture du type généré.
    init(_ emise: Components.Schemas.MontreEmise) {
        self.init(id: emise.id, jeton: JetonMasque(emise.jeton), expireLe: emise.expireLe)
    }
}
