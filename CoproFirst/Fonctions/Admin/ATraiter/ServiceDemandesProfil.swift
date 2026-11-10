// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que la file « Demandes de profil » d'À traiter demande à une installation (#16) :
/// les changements de statut ou de bâtiment qu'un résident a demandés, et leur
/// traitement. Réalisé par `ServiceAPI` (client généré) et `ServiceSimule`, dans ce
/// dossier. Le serveur réserve les deux routes au conseil et à l'administration.
protocol ServiceDemandesProfil: Sendable {
    /// GET /admin/demandes-profil — réponse NON TYPÉE au contrat 1.12.0 : relue par
    /// `Relecture` (besoin noté : coprofirst#2618).
    func demandesProfil(_ installation: Installation) async throws -> [DemandeProfil]
    /// POST /admin/demandes-profil/{id}/traiter — `approuver`, ou `rejeter` avec un motif.
    func traiterDemandeProfil(
        _ id: Int, approuver: Bool, motif: String?, dans installation: Installation
    ) async throws
}

extension ContexteOnglet {
    var serviceDemandesProfil: (any ServiceDemandesProfil)? { service as? any ServiceDemandesProfil }
}

/// Une demande de modification de profil en attente : `DemandeModifRead` et ce que la
/// liste y ajoute (le demandeur, son statut et son bâtiment actuels).
struct DemandeProfil: Decodable, Hashable, Sendable, Identifiable {
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
