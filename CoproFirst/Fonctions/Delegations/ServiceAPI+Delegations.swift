// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Les Délégations par le client GÉNÉRÉ : chaque réponse se lit par son type
/// (`DelegationRead`, `UtilisateurAdminRead`, contrat 1.8.0 — coprofirst#2525).
extension ServiceAPI: ServiceDelegations {
    func delegations(_ installation: Installation) async throws -> [Delegation] {
        switch try await appeler({ try await client(installation.adresse).getDelegations() }) {
        case .ok(let ok): return try ok.body.json.map(Delegation.init)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func residentsDelegables(_ installation: Installation) async throws -> [ResidentDelegable] {
        let (sortie, corps) = try await appeler {
            try await CorpsServi.garder { try await client(installation.adresse).getAdminUtilisateurs() }
        }
        switch sortie {
        case .ok(let ok): return ResidentDelegable.lus(try ok.body.json, corps: corps)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func creerDelegation(_ saisie: SaisieDelegation, dans installation: Installation) async throws -> Delegation {
        guard let mandant = saisie.mandant, let aidant = saisie.aidant else { throw ErreurService.inattendue(422) }
        let corps = Components.Schemas.DelegationCreate(
            aidantId: aidant, dateFin: saisie.dateFin.map(FormatsDuSite.jourISO), mandantId: mandant,
            motif: saisie.motif.trimmingCharacters(in: .whitespacesAndNewlines))
        let sortie = try await appeler { try await client(installation.adresse).postDelegations(body: .json(corps)) }
        switch sortie {
        case .created(let cree): return Delegation(try cree.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func accepterDelegation(_ id: Int, dans installation: Installation) async throws -> Delegation {
        let sortie = try await appeler {
            try await client(installation.adresse).postDelegationsDelegationIdAccepter(path: .init(delegationId: id))
        }
        switch sortie {
        case .ok(let ok): return Delegation(try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func revoquerDelegation(_ id: Int, dans installation: Installation) async throws -> Delegation {
        let sortie = try await appeler {
            try await client(installation.adresse).postDelegationsDelegationIdRevoquer(path: .init(delegationId: id))
        }
        switch sortie {
        case .ok(let ok): return Delegation(try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}
