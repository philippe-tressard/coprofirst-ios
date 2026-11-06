// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que « Délégations aidant » demande à une installation (#15). Réalisé par
/// `ServiceAPI` (client généré) et `ServiceSimule`, dans ce dossier.
///
/// ⚠️ Une délégation est en LECTURE SEULE depuis coprofirst#1534 : l'aidant lit ce que
/// lit la personne aidée, sans agir en son nom. L'app n'a donc aucun « agir pour… ».
protocol ServiceDelegations: Sendable {
    /// GET /delegations : celles que le compte voit (le conseil : toutes ; sinon les siennes),
    /// et qui il est — l'aidant d'une délégation en attente l'accepte.
    func delegations(_ installation: Installation) async throws -> ListeDelegations
    /// GET /admin/utilisateurs : les comptes qu'une délégation peut lier (conseil syndical).
    func residentsDelegables(_ installation: Installation) async throws -> [ResidentDelegable]
    /// POST /delegations (conseil syndical) : la délégation créée, en attente de l'aidant.
    func creerDelegation(_ saisie: SaisieDelegation, dans installation: Installation) async throws -> Delegation
    /// POST /delegations/{id}/accepter (l'aidant) : la délégation devenue active.
    func accepterDelegation(_ id: Int, dans installation: Installation) async throws -> Delegation
    /// POST /delegations/{id}/revoquer (la personne aidée, l'aidant ou le conseil).
    func revoquerDelegation(_ id: Int, dans installation: Installation) async throws -> Delegation
}

extension Parcours {
    /// Le service des Délégations (réalisé par les deux services de l'app :
    /// `DelegationsTests` le vérifie).
    var serviceDelegations: (any ServiceDelegations)? { service as? any ServiceDelegations }
}

/// Une délégation, telle que `routers/delegations.py` la sert (`_to_read`) — relue en
/// miroir : la route n'a pas de `response_model` (coprofirst#2525).
struct Delegation: Decodable, Hashable, Sendable, Identifiable {
    let id: Int
    var mandantId: Int
    /// « ? » quand le compte n'existe plus — le nom tel que le serveur le compose.
    var mandantNom: String
    var aidantId: Int
    var aidantNom: String
    var statut: String
    var motif: String
    /// Jours ISO (`AAAA-MM-JJ`) ; `dateFin` absente : sans limite.
    var dateDebut: String?
    var dateFin: String?
}

/// La liste servie, et l'identifiant du compte qui la lit.
struct ListeDelegations: Hashable, Sendable {
    var delegations: [Delegation]
    var moi: Int
}

/// Un compte qu'une délégation peut lier (`UtilisateurAdmin` du site, champs lus).
struct ResidentDelegable: Decodable, Hashable, Sendable, Identifiable {
    let id: Int
    var prenom: String?
    var nom: String?
    var email: String
    var actif: Bool
}

/// La saisie de « Nouvelle délégation » (`DelegationCreate`).
struct SaisieDelegation: Hashable, Sendable {
    var mandant: Int?
    var aidant: Int?
    var motif = ""
    /// Sans date, la délégation reste valable sans limite.
    var dateFin: Date?

    /// La règle du formulaire du site : deux personnes, distinctes.
    var complete: Bool {
        guard let mandant, let aidant else { return false }
        return mandant != aidant
    }
}

extension Delegation {
    /// Le geste « Accepter » : l'aidant, sur une délégation en attente — la condition du
    /// site, que le serveur vérifie (`exiger_aidant_de_la_delegation`). L'API ne la sert
    /// pas encore (coprofirst#2525).
    func acceptable(par moi: Int) -> Bool { statut == "en_attente" && aidantId == moi }

    /// « Révoquer » : une délégation en attente ou active (le serveur refuse les autres).
    var revocable: Bool { statut == "en_attente" || statut == "active" }

    var libelleStatut: LibelleTeinte { TablesDelegations.statuts[statut] ?? .brut(statut) }
}
