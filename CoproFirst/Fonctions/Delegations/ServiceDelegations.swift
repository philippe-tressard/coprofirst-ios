// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que « Délégations aidant » demande à une installation (#15). Réalisé par
/// `ServiceAPI` (client généré) et `ServiceSimule`, dans ce dossier.
///
/// ⚠️ Une délégation est en LECTURE SEULE depuis coprofirst#1534 : l'aidant lit ce que
/// lit la personne aidée, sans agir en son nom. L'app n'a donc aucun « agir pour… ».
protocol ServiceDelegations: Sendable {
    /// GET /delegations : celles que le compte voit (le conseil : toutes ; sinon les
    /// siennes), chacune avec les gestes que le serveur lui ouvre.
    func delegations(_ installation: Installation) async throws -> [Delegation]
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

/// Une délégation, telle que le serveur la sert (`DelegationRead`, coprofirst#2525).
struct Delegation: Hashable, Sendable, Identifiable {
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
    /// Les gestes que le serveur ouvre au compte qui lit (#56) : l'app ne les déduit
    /// ni du statut ni de qui est l'aidant. La réponse d'un geste porte ceux d'après.
    var peutAccepter = false
    var peutRevoquer = false
}

extension Delegation {
    init(_ lue: Components.Schemas.DelegationRead) {
        self.init(
            id: lue.id, mandantId: lue.mandantId, mandantNom: lue.mandantNom, aidantId: lue.aidantId,
            aidantNom: lue.aidantNom, statut: lue.statut, motif: lue.motif, dateDebut: lue.dateDebut,
            dateFin: lue.dateFin, peutAccepter: lue.peutAccepter ?? false, peutRevoquer: lue.peutRevoquer ?? false)
    }

    var libelleStatut: LibelleTeinte { TablesDelegations.statuts[statut] ?? .brut(statut) }
}

/// Un compte qu'une délégation peut lier (`UtilisateurAdminRead`, champs lus).
struct ResidentDelegable: Hashable, Sendable, Identifiable {
    let id: Int
    var email: String
    var actif: Bool
    /// « Prénom NOM », tel que le serveur l'affiche (`nom_affiche`, #135).
    var nomAffiche: String
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

extension ResidentDelegable {
    /// Le compte servi, par son type GÉNÉRÉ — le même branchement pour le service réel et
    /// l'API simulée.
    init(_ lu: Components.Schemas.UtilisateurAdminRead) {
        self.init(id: lu.id, email: lu.email, actif: lu.actif, nomAffiche: lu.nomAffiche)
    }
}
