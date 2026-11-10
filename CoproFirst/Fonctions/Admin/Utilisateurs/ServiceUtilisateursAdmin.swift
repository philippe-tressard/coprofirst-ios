// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que l'onglet « Utilisateurs » demande à une installation (#16) : tous les comptes,
/// et les gestes que l'app porte — interdire ou réautoriser la communauté, relancer le
/// rapprochement des lots, supprimer. Modifier la fiche, les rôles et l'accueil d'un
/// arrivant restent au site : qui peut recevoir ou perdre un rôle se décide dans le front
/// du site, que l'app ne recopie pas (coprofirst#2618). Réalisé par `ServiceAPI` (client
/// généré) et `ServiceSimule`.
protocol ServiceUtilisateursAdmin: Sendable {
    /// GET /admin/utilisateurs (conseil et administration).
    func utilisateurs(_ installation: Installation) async throws -> [UtilisateurAdmin]
    /// PATCH /admin/utilisateurs/{id}/ban-communaute (administration) — rend l'état servi.
    func bannirCommunaute(_ id: Int, interdit: Bool, dans installation: Installation) async throws -> BanCommunaute
    /// POST /admin/utilisateurs/{id}/auto-match (conseil et administration) — l'annonce
    /// du serveur, avec son ton.
    func relancerRapprochement(_ id: Int, dans installation: Installation) async throws -> PhraseAvis
    /// DELETE /admin/utilisateurs/{id} (administration) — définitif.
    func supprimerUtilisateur(_ id: Int, dans installation: Installation) async throws
}

extension ContexteOnglet {
    var serviceUtilisateurs: (any ServiceUtilisateursAdmin)? { service as? any ServiceUtilisateursAdmin }
}

/// Un compte, tel que l'administration le lit (`UtilisateurAdminRead`).
struct UtilisateurAdmin: Hashable, Sendable, Identifiable {
    let id: Int
    var prenom: String
    var nom: String
    var email: String
    var statut: String
    /// Les rôles portés ; `role` seul si la liste est vide (`aRole` du site).
    var roles: [String]
    var actif: Bool
    var emailVerifie: Bool
    var batimentNom: String?
    /// Le bailleur d'un locataire.
    var nomProprietaire: String?
    var aDesLots: Bool
    /// Loti, TC, Vigik, Bail : `ok`, `manque` ou `sans_objet`, par le serveur.
    var etiquettes: [String: String]
    var ban: BanCommunaute
    /// Averti de sa suppression pour inactivité ; s'efface à la reconnexion.
    var purgeAvertieLe: Date?
    var derniereConnexion: Date?
    var creeLe: Date
}

/// Ce que le serveur dit de l'accès d'un compte à la communauté.
struct BanCommunaute: Hashable, Sendable {
    var interdit: Bool
    var jusquAu: Date?

    /// Banni : pour de bon, ou jusqu'à une date encore à venir (la lecture du site).
    func banni(maintenant: Date = .now) -> Bool {
        interdit || (jusquAu.map { $0 > maintenant } ?? false)
    }
}

extension UtilisateurAdmin {
    init(_ lu: Components.Schemas.UtilisateurAdminRead) {
        let roles = lu.roles ?? []
        self.init(
            id: lu.id, prenom: lu.prenom, nom: lu.nom, email: lu.email, statut: lu.statut.rawValue,
            roles: roles.isEmpty ? [lu.role.rawValue] : roles, actif: lu.actif, emailVerifie: lu.emailVerifie ?? false,
            batimentNom: lu.batimentNom, nomProprietaire: lu.nomProprietaire, aDesLots: lu.hasLots,
            etiquettes: [
                "loti": lu.etiquettes.loti, "tc": lu.etiquettes.tc, "vigik": lu.etiquettes.vigik,
                "bail": lu.etiquettes.bail,
            ],
            ban: BanCommunaute(interdit: lu.communauteInterdit ?? false, jusquAu: lu.communauteBanJusquAu),
            purgeAvertieLe: lu.purgeAvertieLe, derniereConnexion: lu.derniereConnexion, creeLe: lu.creeLe)
    }
}

extension BanCommunaute {
    init(_ lu: Components.Schemas.UserRead) {
        self.init(interdit: lu.communauteInterdit ?? false, jusquAu: lu.communauteBanJusquAu)
    }
}
