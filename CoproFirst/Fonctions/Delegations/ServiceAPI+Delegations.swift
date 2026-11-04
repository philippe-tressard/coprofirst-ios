// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Les Délégations par le client GÉNÉRÉ. Aucune de leurs réponses n'est typée dans le
/// contrat (`response_model=list[dict]`, ou rien) : elles se relisent en miroir
/// (`Relecture`) — besoin noté pour coprofirst#2525.
extension ServiceAPI: ServiceDelegations {
    func delegations(_ installation: Installation) async throws -> ListeDelegations {
        let client = client(installation.adresse)
        async let liste = appeler { try await client.getDelegations() }
        async let compte = appeler { try await client.getAuthMe() }
        let delegations: [Delegation] =
            switch try await liste {
            case .ok(let ok): try Relecture.lire([Delegation].self, depuis: try ok.body.json)
            case .unprocessableContent: throw ErreurService.inattendue(422)
            case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
            }
        switch try await compte {
        case .ok(let ok): return ListeDelegations(delegations: delegations, moi: try ok.body.json.id)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func residentsDelegables(_ installation: Installation) async throws -> [ResidentDelegable] {
        switch try await appeler({ try await client(installation.adresse).getAdminUtilisateurs() }) {
        case .ok(let ok): return try Relecture.lire([ResidentDelegable].self, depuis: try ok.body.json)
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
        case .created(let cree): return try Relecture.lire(Delegation.self, depuis: try cree.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func accepterDelegation(_ id: Int, dans installation: Installation) async throws -> Delegation {
        let sortie = try await appeler {
            try await client(installation.adresse).postDelegationsDelegationIdAccepter(path: .init(delegationId: id))
        }
        switch sortie {
        case .ok(let ok): return try Relecture.lire(Delegation.self, depuis: try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func revoquerDelegation(_ id: Int, dans installation: Installation) async throws -> Delegation {
        let sortie = try await appeler {
            try await client(installation.adresse).postDelegationsDelegationIdRevoquer(path: .init(delegationId: id))
        }
        switch sortie {
        case .ok(let ok): return try Relecture.lire(Delegation.self, depuis: try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}
