// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que dit la confirmation d'un geste de rôle — la modale du site
/// (`OngletUtilisateurs.svelte`, coprofirst v3.88.1) : la question, puis sa suite.
///
/// Sur le compte du lecteur (`pourSoi` : l'`id` servi par `GET /auth/me`, gardé avec le
/// profil, #94), la question dit « votre compte », et la suite ce qu'il perd en se
/// retirant l'administration ; rien sur ses autres rôles. Sur un autre compte, son nom
/// servi, et la notification qu'il recevra. Un lecteur inconnu (profil gardé avant #94)
/// n'est le titulaire d'aucun compte : la confirmation dit la notification.
struct ConfirmationRole: Equatable {
    let question: String
    let suite: String?

    init(_ offert: GesteDeRole, sur compte: UtilisateurAdmin, lecteur: Int?) {
        let pourSoi = lecteur == compte.id
        let destinataire = pourSoi ? TextesUtilisateursAdmin.votreCompte : compte.nomAffiche
        question = TextesUtilisateursAdmin.confirmerRole(offert, destinataire)
        if !pourSoi {
            suite = TextesUtilisateursAdmin.notifie
        } else if offert.geste == .retirer, offert.role == "admin" {
            suite =
                compte.roles.contains("operateur")
                ? TextesUtilisateursAdmin.garderaLaSupervision : TextesUtilisateursAdmin.perdraLAdministration
        } else {
            suite = nil
        }
    }
}

extension UtilisateurAdmin {
    /// « Opérateur désigné par l'exploitant » (`GestesRolesCompte.svelte`) : ce que l'écran
    /// DIT, pas ce qu'il offre — sur une instance commune (`operateur_par_exploitant` servi
    /// par `GET /config`), un compte actif qui porte le rôle et dont le serveur n'offre aucun
    /// geste d'opérateur. Gestes non servis : rien n'est dit. Aucun geste n'en dépend (#94).
    func operateurDesigneParLExploitant(instanceCommune: Bool) -> Bool {
        guard instanceCommune, actif, roles.contains("operateur"), let gestes = gestesRoles else { return false }
        return !gestes.contains { $0.role == "operateur" }
    }
}
