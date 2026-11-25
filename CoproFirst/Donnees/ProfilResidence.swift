// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Qui est l'utilisateur DANS une résidence : son statut, ses rôles, son logement.
/// Ils diffèrent d'une copropriété à l'autre — chaque résidence garde le sien.
struct ProfilResidence: Codable, Hashable, Sendable {
    var statut: String?
    var roles: [String]
    /// « Bât. A, T3, 2ème » — le libellé du logement, TEL QUE LE SERVEUR LE SERT.
    ///
    /// Le serveur le compose (`libelle_logement` de `GET /auth/me`, contrat ≥ 1.2.0,
    /// CoproFirst ≥ 3.61.0, coprofirst#2500) : l'app l'affiche sans règle à elle. Absent
    /// ou `null` — serveur plus ancien, rien à dire — : rien ne s'affiche.
    var libelleLogement: String?
    /// Les PUBLICS du menu auxquels le compte appartient (`acces_menu` de GET /auth/me,
    /// contrat 2.11.0, coprofirst#3003) — calculés par le serveur, lus par `PagesOuvertes`
    /// (#355). `nil` : un profil gardé avant #355, jusqu'à sa relecture à l'ouverture.
    var accesMenu: [String]?
    /// La saisie d'une affaire qui s'applique au compte, `essentielle` ou `complete`
    /// (`saisie_affaire_effective`, contrat ≥ 1.14.0, #69) : le choix du Profil, sinon le
    /// défaut — calculé par le SERVEUR, l'app le lit. Facultatif : un profil gardé avant
    /// #69 se relit sans lui.
    var saisieAffaire: String?
    /// Conseil syndical ou administration, tel que le SERVEUR le juge (`est_moderateur`,
    /// contrat 1.25.0, #136) : lu par `DroitsOnglet`. `nil` (non servi, ou profil gardé
    /// avant #136, jusqu'à sa relecture) vaut « non », comme au site.
    var estModerateur: Bool?
    /// L'identifiant du compte dans cette résidence (`id` de `GET /auth/me`) : il dit quel
    /// compte de la liste d'« Utilisateurs » est celui du lecteur — la confirmation d'un
    /// geste de rôle dit alors « votre compte », comme le site (`pourSoi`, #94). Gardé
    /// avec le profil, au coffre ; la déconnexion l'efface (`oublierLeCompte`), le
    /// prochain `GET /auth/me` le redit. Facultatif : un profil gardé avant #94 se relit
    /// sans lui, et la confirmation dit alors « Cette personne recevra une notification. »
    var idCompte: Int?
    /// Le compte a refusé la mesure d'audience (`opt_out_telemetrie` de `GET /auth/me`) :
    /// l'app ne note alors aucune page vue (`MesureAudience`, coprofirst#2726). `nil` (profil
    /// gardé avant, jusqu'à sa relecture à l'ouverture) : refus inconnu, rien ne se note.
    var refusMesure: Bool?
    /// Le mot de passe est TEMPORAIRE (`mot_de_passe_a_changer`, contrat 2.12.0, #377) : les
    /// deux comptes initiaux d'une installation neuve. Tant qu'il tient, l'app n'ouvre que
    /// « Choisir votre mot de passe » (`MotDePasseTemporaireView`) ; `nil` vaut « non ».
    var motDePasseAChanger: Bool?

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

extension ProfilResidence {
    /// Le compte servi par `GET /auth/me`, `est_moderateur` compris (contrat 1.25.0, #136)
    /// — le MÊME branchement pour toute lecture du profil.
    init(_ moi: Components.Schemas.UserRead) {
        // Le libellé du logement, composé par le serveur (contrat ≥ 1.2.0, coprofirst#2500) :
        // affiché tel quel. Un serveur plus ancien ne le sert pas — `nil`, rien ne s'affiche.
        self.init(
            statut: moi.statut.rawValue, roles: (moi.roles ?? []) + [moi.role.rawValue],
            libelleLogement: moi.libelleLogement, accesMenu: moi.accesMenu ?? [],
            saisieAffaire: moi.saisieAffaireEffective, estModerateur: moi.estModerateur, idCompte: moi.id,
            refusMesure: moi.optOutTelemetrie ?? false, motDePasseAChanger: moi.motDePasseAChanger ?? false)
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
