// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

// #94 : deux nuances du site autour des gestes de rôle — elles ne changent aucun geste
// offert, seulement ce que la fiche d'un compte DIT (`GestesRolesCompte.svelte`,
// `OngletUtilisateurs.svelte`, coprofirst v3.88.1).

private func compte(_ id: Int) throws -> UtilisateurAdmin {
    try #require(try FixturesUtilisateursAdmin.lus().first { $0.id == id })
}

private let retirerAdmin = GesteDeRole(role: "admin", geste: .retirer)
private let retirerCS = GesteDeRole(role: "conseil_syndical", geste: .retirer)
private let ajouterCS = GesteDeRole(role: "conseil_syndical", geste: .ajouter)

// MARK: - « votre compte »

@Test func surUnAutreCompteLaConfirmationNommeEtDitLaNotification() throws {
    let alix = try compte(13)
    let dite = ConfirmationRole(ajouterCS, sur: alix, lecteur: 11)
    #expect(dite.question == "Ajouter le rôle Conseil syndical à Alix MODÈLE ?")
    #expect(dite.suite == "Cette personne recevra une notification.")
}

@Test func surSonCompteLAdministrateurLitVotreCompteEtCeQuIlPerd() throws {
    var camille = try compte(11)
    let dite = ConfirmationRole(retirerAdmin, sur: camille, lecteur: 11)
    #expect(dite.question == "Retirer le rôle Admin de votre compte ?")
    #expect(dite.suite == "Vous perdrez aussitôt l'accès à l'administration.")
    // Opérateur aussi : il n'y garde que la supervision.
    camille.roles.append("operateur")
    #expect(
        ConfirmationRole(retirerAdmin, sur: camille, lecteur: 11).suite
            == "Vous n'y garderez que la supervision de la plateforme.")
}

@Test func surSonCompteUnAutreRoleNeDitNiPerteNiNotification() throws {
    let dite = ConfirmationRole(retirerCS, sur: try compte(11), lecteur: 11)
    #expect(dite.question == "Retirer le rôle Conseil syndical de votre compte ?")
    #expect(dite.suite == nil)
}

/// Un profil gardé avant #94 ne sait pas son compte : la confirmation dit, comme avant,
/// le nom et la notification — jamais « votre compte » deviné.
@Test func unLecteurInconnuNEstLeTitulaireDAucunCompte() throws {
    let dite = ConfirmationRole(retirerAdmin, sur: try compte(11), lecteur: nil)
    #expect(dite.question == "Retirer le rôle Admin de Camille EXEMPLE ?")
    #expect(dite.suite == "Cette personne recevra une notification.")
}

/// L'identifiant se lit de `GET /auth/me`, par le type généré.
@Test func leProfilGardeLIdentifiantServiDuCompte() throws {
    let json = #"""
        {"id": 11, "prenom": "Camille", "nom": "Exemple", "nom_affiche": "Camille EXEMPLE",
         "nom_aide_affiche": "", "email": "camille.exemple@exemple.fr", "statut": "copropriétaire_résident",
         "role": "propriétaire", "roles": ["admin"], "actif": true, "onboarding_complete": true,
         "onboarding_etape": 4, "preferences_notifications": "{}", "cree_le": "2026-01-01T10:00:00"}
        """#
    let profil = ProfilResidence(try Relecture.generee(Components.Schemas.UserRead.self, json: json))
    #expect(profil.idCompte == 11)
}

/// La déconnexion efface l'identifiant du compte ; le reste du profil demeure, et le
/// prochain `GET /auth/me` le redit.
@MainActor
@Test func laDeconnexionEffaceLIdentifiantDuCompte() async throws {
    let suite = "tests.\(UUID().uuidString)"
    let reglages = try #require(UserDefaults(suiteName: suite))
    defer { reglages.removePersistentDomain(forName: suite) }
    let coffre = CoffreEnMemoire()
    let service = ServiceSimule(delai: .milliseconds(1))
    let parcours = Parcours(service: service, connues: InstallationsConnues(reglages: reglages, coffre: coffre))
    let residence = ServiceSimule.residence
    parcours.ouvrir(residence)
    await parcours.rafraichirProfil()
    #expect(parcours.ouverteAJour?.profil?.idCompte == 11, "le compte du lecteur, servi")

    await parcours.deconnecter(residence)

    let gardee = parcours.connues.liste.first { $0.adresse == residence.adresse }
    #expect(gardee?.profil?.idCompte == nil, "l'identifiant part avec la session")
    #expect(gardee?.profil?.roles == service.profilSimule.roles, "le reste du profil demeure")
    let relance = InstallationsConnues(reglages: reglages, coffre: coffre)
    #expect(relance.liste.first?.profil?.idCompte == nil, "…et au coffre aussi")
}

// MARK: - « Opérateur désigné par l'exploitant »

@Test func lInstanceCommuneSeLitDansLaConfigServie() throws {
    let adresse = try #require(URL(string: "https://tilleuls.exemple.fr"))
    let commune = Installation(adresse: adresse, config: ["site_nom": "Les Tilleuls", "operateur_par_exploitant": "1"])
    #expect(commune?.operateurParExploitant == true)
    let propre = Installation(adresse: adresse, config: ["site_nom": "Les Tilleuls", "operateur_par_exploitant": "0"])
    #expect(propre?.operateurParExploitant == false)
    #expect(Installation(adresse: adresse, config: ["site_nom": "Les Tilleuls"])?.operateurParExploitant == false)
}

@Test func lOperateurDesigneParLExploitantSeDitSansGesteServi() throws {
    let sacha = try compte(15)
    #expect(sacha.operateurDesigneParLExploitant(instanceCommune: true))
    #expect(!sacha.operateurDesigneParLExploitant(instanceCommune: false), "hors instance commune, rien")
    // Un geste d'opérateur servi passe avant le texte, comme sur le site.
    var servi = sacha
    servi.gestesRoles = [GesteDeRole(role: "operateur", geste: .retirer)]
    #expect(!servi.operateurDesigneParLExploitant(instanceCommune: true))
    // Un compte sans le rôle, ou inactif : rien.
    #expect(!(try compte(11)).operateurDesigneParLExploitant(instanceCommune: true))
    var inactif = sacha
    inactif.actif = false
    #expect(!inactif.operateurDesigneParLExploitant(instanceCommune: true))
    #expect(TextesUtilisateursAdmin.operateurParExploitant == "Opérateur désigné par l’exploitant")
}
