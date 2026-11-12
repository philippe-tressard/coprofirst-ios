// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que la file « Demandes de profil » d'À traiter demande à une installation (#16) :
/// les changements de statut ou de bâtiment qu'un résident a demandés, et leur
/// traitement. Réalisé par `ServiceAPI` (client généré) et `ServiceSimule`, dans ce
/// dossier. Le serveur réserve les deux routes au conseil et à l'administration.
protocol ServiceDemandesProfil: Sendable {
    /// GET /admin/demandes-profil → `[DemandeProfilEnAttente]` (typé depuis le contrat
    /// 1.16.0, coprofirst#2618).
    func demandesProfil(_ installation: Installation) async throws -> [DemandeProfil]
    /// POST /admin/demandes-profil/{id}/traiter — `approuver`, ou `rejeter` avec un motif.
    /// Rend l'annonce SERVIE (`annonce`, contrat 1.16.0, #87) ; `nil` d'une installation
    /// antérieure, qui ne la sert pas.
    func traiterDemandeProfil(
        _ id: Int, approuver: Bool, motif: String?, dans installation: Installation
    ) async throws -> PhraseAvis?
}

extension ContexteOnglet {
    var serviceDemandesProfil: (any ServiceDemandesProfil)? { service as? any ServiceDemandesProfil }
}

/// Une demande de modification de profil en attente : `DemandeModifRead` et ce que la
/// liste y ajoute (le demandeur, son statut et son bâtiment actuels).
struct DemandeProfil: Hashable, Sendable, Identifiable {
    let id: Int
    var utilisateurNom: String
    var utilisateurEmail: String?
    var statutActuel: String?
    var batimentActuel: String?
    var statutSouhaite: String?
    var batimentNomSouhaite: String?
    var motif: String?
    var creeLe: Date
}

extension DemandeProfil {
    init(_ lue: Components.Schemas.DemandeProfilEnAttente) {
        self.init(
            id: lue.id, utilisateurNom: lue.utilisateurNom, utilisateurEmail: lue.utilisateurEmail,
            statutActuel: lue.statutActuel, batimentActuel: lue.batimentActuel, statutSouhaite: lue.statutSouhaite,
            batimentNomSouhaite: lue.batimentNomSouhaite, motif: lue.motif, creeLe: lue.creeLe)
    }
}
