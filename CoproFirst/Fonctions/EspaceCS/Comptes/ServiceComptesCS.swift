// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que l'onglet « Comptes & accès » demande à une installation (#15) — la file de
/// travail du conseil : les comptes à valider, les demandes de badges et de
/// télécommandes. Réalisé par `ServiceAPI` (client généré) et `ServiceSimule`, dans ce
/// dossier. Le serveur refuse chaque route à qui n'est pas du conseil.
protocol ServiceComptesCS: Sendable {
    /// GET /admin/comptes-en-attente.
    func comptesEnAttente(_ installation: Installation) async throws -> [CompteEnAttente]
    /// GET /admin/commandes-acces (réponse non typée : `Relecture`).
    func commandesEnAttente(_ installation: Installation) async throws -> [CommandeEnAttente]
    /// POST /admin/comptes/{id}/traiter — `valider` ou `refuser`.
    func traiterCompte(_ id: Int, valider: Bool, dans installation: Installation) async throws
    /// POST /admin/utilisateurs/{id}/accueil-arrivant : bienvenue, consignes, demandes
    /// au syndic et au conseil, pour un résident qui emménage.
    func accueillir(_ id: Int, _ accueil: AccueilArrivant, dans installation: Installation) async throws
    /// POST /admin/commandes-acces/{id}/traiter — accepter (avec les codes remis, s'il y
    /// en a : le serveur les pose sur le lot commandé) ou refuser.
    func traiterCommande(_ id: Int, accepter codes: [String]?, dans installation: Installation) async throws
}

extension ContexteOngletCS {
    var serviceComptes: (any ServiceComptesCS)? { service as? any ServiceComptesCS }
}

/// Un compte en attente de validation (`UserRead`, ce que la carte en montre).
struct CompteEnAttente: Hashable, Sendable, Identifiable {
    let id: Int
    var prenom: String
    var nom: String
    var statut: String
    /// Le bâtiment tel que le serveur le nomme.
    var batimentNom: String?
    /// L'aidé, pour un compte d'aidant ou de mandataire.
    var prenomAide: String?
    var nomAide: String?
    var creeLe: Date
}

/// Une demande de badge ou de télécommande en attente (`/admin/commandes-acces`).
struct CommandeEnAttente: Decodable, Hashable, Sendable, Identifiable {
    let id: Int
    var type: String
    var quantite: Int
    var demandeurNom: String
    /// Le lot, tel que le serveur le libelle.
    var lot: String
    var batiment: String?
    var creeLe: Date
}

/// Ce que la case « Nouvel Arrivant » envoie (`AccueilArrivantBody`).
struct AccueilArrivant: Hashable, Sendable {
    var batiment = ""
    var ancienResident = ""
}
