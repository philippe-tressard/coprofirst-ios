// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Qui est l'utilisateur DANS une résidence : son statut, ses rôles, son logement.
/// Ils diffèrent d'une copropriété à l'autre — chaque résidence garde le sien.
struct ProfilResidence: Codable, Hashable, Sendable {
    var statut: String?
    var roles: [String]
    /// « Bât. A, T3, 2ème » — le libellé du logement, TEL QUE LE SERVEUR LE SERT.
    ///
    /// Le site le compose (`libelleLogement`, `#lib/utils.ts`) à partir des lots et
    /// de l'étage ; cette règle est du code, pas une table : l'app ne la réécrit pas.
    /// Tant que l'API ne sert pas ce libellé (besoin noté pour coprofirst#2460), il
    /// reste absent et rien ne s'affiche.
    var libelleLogement: String?

    /// Les rôles comme l'en-tête de l'accueil les annonce : le statut, puis les rôles
    /// qui ajoutent quelque chose (`misEnAvant`), sans doublon — `EnteteAccueil.svelte`.
    var rolesAffiches: [String] {
        var libelles: [String] = []
        if let statut, RolesUtilisateur.libellesStatut[statut] != nil {
            libelles.append(RolesUtilisateur.libelleStatut(statut))
        }
        let tous = Set(roles)
        for role in RolesUtilisateur.misEnAvant where tous.contains(role) {
            libelles.append(RolesUtilisateur.libelleRole(role))
        }
        return libelles
    }
}

extension RolesUtilisateur {
    /// Une clé inconnue est rendue telle quelle : un libellé manquant doit se voir
    /// (`libelleRole` du site).
    static func libelleRole(_ role: String) -> String {
        libellesRole[role] ?? libellesHerites[role] ?? libellesStatut[role] ?? role
    }

    static func libelleStatut(_ statut: String) -> String {
        libellesStatut[statut] ?? libellesHerites[statut] ?? libellesRole[statut] ?? statut
    }
}
