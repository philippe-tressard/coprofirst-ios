// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que l'onglet « Utilisateurs » demande à une installation (#16) : tous les comptes,
/// et les gestes que l'app porte — interdire ou réautoriser la communauté, donner ou
/// retirer un rôle, relancer le rapprochement des lots, supprimer. Les gestes de rôle
/// sont ceux que le SERVEUR sert avec chaque compte (`gestes_roles`, coprofirst#2618,
/// #89) : l'app ne recompose pas la règle. Modifier la fiche et
/// l'accueil d'un arrivant restent au site. Réalisé par `ServiceAPI` (client généré) et
/// `ServiceSimule`.
protocol ServiceUtilisateursAdmin: Sendable {
    /// GET /admin/utilisateurs (conseil et administration).
    func utilisateurs(_ installation: Installation) async throws -> [UtilisateurAdmin]
    /// POST /admin/utilisateurs/{id}/ajouter-role | retirer-role (administration) — un
    /// geste SERVI (`gestes_roles`) ; la liste se relit ensuite, les gestes d'un compte
    /// dépendant des autres.
    func changerRole(_ id: Int, role: String, geste: GesteRole, dans installation: Installation) async throws
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
    /// Les gestes de rôle que le serveur offre sur ce compte (`gestes_roles`) ; aucun :
    /// rien à offrir.
    var gestesRoles: [GesteDeRole]
    /// Averti de sa suppression pour inactivité ; s'efface à la reconnexion.
    var purgeAvertieLe: Date?
    var derniereConnexion: Date?
    var creeLe: Date
    /// « Prénom NOM », tel que le serveur l'affiche (`nom_affiche`, #135).
    var nomAffiche: String
}

/// Ce que le serveur dit de l'accès d'un compte à la communauté.
struct BanCommunaute: Hashable, Sendable {
    var interdit: Bool
    var jusquAu: Date?
    /// `communaute_banni` : exclu À CET INSTANT, jugé à l'heure du SERVEUR — l'app ne
    /// compare pas `jusquAu` à l'heure du téléphone.
    var banni: Bool
}

/// Un geste de rôle, tel que le serveur le sert et que sa route le nomme.
enum GesteRole: String, Hashable, Sendable {
    case ajouter, retirer
}

/// Un geste de rôle offert sur un compte (`gestes_roles`, `utils/gestes_roles` du
/// serveur) : le rôle, tel que la route le nomme, et ce qu'on peut en faire.
struct GesteDeRole: Hashable, Sendable, Identifiable {
    let role: String
    let geste: GesteRole
    var id: String { role }
}

extension GesteDeRole {
    /// Les gestes servis (`GestesRoles`), dans l'ordre du site (`GestesRolesCompte.svelte`) ;
    /// un rôle servi `null` n'offre rien.
    static func servis(_ lus: Components.Schemas.GestesRoles) -> [GesteDeRole] {
        let servis: [(String, String?)] = [
            ("conseil_syndical", lus.conseilSyndical?.rawValue), ("admin", lus.admin?.rawValue),
            ("operateur", lus.operateur?.rawValue),
        ]
        return servis.compactMap { role, geste in
            geste.flatMap(GesteRole.init).map { GesteDeRole(role: role, geste: $0) }
        }
    }
}

extension UtilisateurAdmin {
    /// Le compte servi, par son type GÉNÉRÉ — le même branchement pour le service réel et
    /// l'API simulée.
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
            ban: BanCommunaute(
                interdit: lu.communauteInterdit ?? false, jusquAu: lu.communauteBanJusquAu,
                banni: lu.communauteBanni ?? false),
            gestesRoles: GesteDeRole.servis(lu.gestesRoles),
            purgeAvertieLe: lu.purgeAvertieLe, derniereConnexion: lu.derniereConnexion, creeLe: lu.creeLe,
            nomAffiche: lu.nomAffiche)
    }
}

extension BanCommunaute {
    /// L'état que rend un geste (`UserRead`).
    init(_ lu: Components.Schemas.UserRead) {
        self.init(
            interdit: lu.communauteInterdit ?? false, jusquAu: lu.communauteBanJusquAu,
            banni: lu.communauteBanni ?? false)
    }
}
