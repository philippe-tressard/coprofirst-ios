// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

// Ce que le serveur dit d'une PERSONNE, lu par les types générés au lieu d'être recomposé
// (coprofirst#2633, #2680) : le nom affiché (#135), « modère » (#136), l'auteur d'un
// message et « le mien » (#138). Un champ facultatif non servi vaut « non » (défaut
// fermé) : aucun rôle, aucun identifiant ne le remplace.

/// Un compte `UserRead`, avec `extra` ajouté tel quel au JSON servi.
private func compte(_ id: Int, roles: String, _ extra: String = "") -> String {
    #"""
    {"id": \#(id), "prenom": "Jean-Baptiste", "nom": "Fort", "nom_affiche": "Jean-Baptiste FORT",
     "nom_aide_affiche": "", "email": "jb@exemple.fr", "statut": "copropriétaire_résident",
     "role": "propriétaire", "roles": \#(roles), "actif": true, "onboarding_complete": true,
     "onboarding_etape": 4, "preferences_notifications": "{}", "cree_le": "2026-01-01T10:00:00"
    """# + extra + "}"
}

private func profil(roles: String, _ extra: String = "") throws -> ProfilResidence {
    ProfilResidence(try Relecture.generee(Components.Schemas.UserRead.self, json: compte(5, roles: roles, extra)))
}

// MARK: - #135 : le nom affiché

/// Le repli sur le prénom et le nom ne sert plus qu'à une saisie pas encore enregistrée
/// (une fiche de l'annuaire renommée) et à un annuaire gardé en cache avant #135.
@Test func leNomServiPrimeEtLeRepliNeVitQuEnUnEndroit() {
    let servi = "Jean-Baptiste FORT"
    #expect(FormatsDuSite.nom(affiche: servi, prenom: "Jean-Baptiste", nom: "Fort") == servi)
    #expect(FormatsDuSite.nom(affiche: nil, prenom: "Jean-Baptiste", nom: "Fort") == "Jean-Baptiste Fort")
    #expect(FormatsDuSite.nom(affiche: "  ", prenom: "Jean-Baptiste", nom: nil) == "Jean-Baptiste", "servi vide")
    #expect(FormatsDuSite.nom(affiche: "", prenom: nil, nom: nil) == FormatsDuSite.tiret)
}

@Test func leCompteDuProfilSeNommeParLeServeur() throws {
    let lu = try Relecture.generee(Components.Schemas.UserRead.self, json: compte(5, roles: "[]"))
    #expect(Compte(lu: lu).nomAffiche == "Jean-Baptiste FORT")
}

@Test func laFileDesComptesNommeLeCompteEtLaPersonneAidee() throws {
    let comptes = try FixturesComptesCS.comptesLus()
    #expect(comptes.map(\.nomAffiche) == ["Camille EXEMPLE", "Dominique FICTIF", "Alix MODÈLE"])
    #expect(comptes.map(\.nomAideAffiche) == [nil, nil, "Claude FICTIF"], "servi vide : personne n'est aidé")
}

@Test func lesComptesDeLAdministrationEtDesDelegationsSeNommentParLeServeur() throws {
    #expect(try FixturesUtilisateursAdmin.lus().first { $0.id == 13 }?.nomAffiche == "Alix MODÈLE")
    #expect(try FixturesDelegations.residentsLus().first { $0.id == 4 }?.nomAffiche == "Marc DÉMO")
}

@Test func unBailNommeSonLocataireEtSonBailleurParLeServeur() throws {
    let baux = try FixturesAcces.bauxLus()
    #expect(baux.first { $0.id == 3 }?.nomLocataire == "Locataire DU LOT 31")
    #expect(try FixturesAcces.monBailLu().nomBailleur == "Sacha EXEMPLE")
    // Un bail sans nom de locataire : le serveur sert un nom vide, l'écran un tiret.
    let sansNom = FixturesAcces.baux.replacingOccurrences(
        of: #""locataire_nom_affiche": "Locataire DU LOT 32""#, with: #""locataire_nom_affiche": """#)
    let lus = try Relecture.generee([Components.Schemas.BailOut].self, json: sansNom).map(Bail.init)
    #expect(lus.first { $0.id == 4 }?.nomLocataire == FormatsDuSite.tiret)
}

@Test func lesContactsDUnPrestataireSeNommentParLeServeurDansLOrdreServi() throws {
    let servi = #"""
        [{"id": 8, "nom": "Ascenseurs Exemple", "specialite": "ascenseur", "actif": true, "telephones": [],
          "contacts": [
            {"prenom": "Jean-Baptiste", "nom": "Fort", "fonction": "Technicien", "telephone": "01", "email": null,
             "nom_affiche": "Jean-Baptiste FORT"},
            {"prenom": null, "nom": null, "fonction": "Astreinte", "telephone": "02", "email": null, "nom_affiche": ""}
          ]}]
        """#
    let generes = try Relecture.generee([Components.Schemas.PrestataireRead].self, json: servi)
    let contacts = try #require(generes.map(Prestataire.init).first).contacts
    #expect(contacts.map(\.nomAffiche) == ["Jean-Baptiste FORT", nil], "sans nom : rien")
}

@Test func lAnnuaireDitLaCiviliteEtLeNomServi() {
    let membre = Annuaire.Membre(
        id: 1, genre: "M.", prenom: "Jean-Baptiste", nom: "Fort", nomServi: "Jean-Baptiste FORT")
    #expect(membre.nomComplet == "M. Jean-Baptiste FORT")
    let gardeAvant = Annuaire.Membre(id: 1, genre: "M.", prenom: "Jean-Baptiste", nom: "Fort")
    #expect(gardeAvant.nomComplet == "M. Jean-Baptiste Fort", "un annuaire gardé avant #135")
}

/// Une fiche du conseil en cours de saisie n'a plus de nom servi : la saisie se nomme par
/// le repli jusqu'à l'enregistrement (l'écran de `POST /noms/affiche` est un lot à part).
@Test func uneFicheRenommeePerdSonNomServi() throws {
    var membre = try #require(try FixturesAnnuaireCS.conseilLu().membres.first)
    let servi = membre.nomAffiche
    #expect(membre.nomServi != nil && servi == membre.nomServi)
    membre.estPresident = true
    #expect(membre.nomAffiche == servi, "un autre champ ne périme pas le nom")
    membre.nom = "Fort"
    #expect(membre.nomServi == nil)
    #expect(membre.nomAffiche == FormatsDuSite.nom(affiche: nil, prenom: membre.prenom, nom: "Fort"))
}

// MARK: - #136 : modérer se lit

@Test func estModerateurServiFaitFoiSurLesRoles() throws {
    let horsConseil = try profil(roles: #"["conseil_syndical"]"#, #", "est_moderateur": false"#)
    #expect(horsConseil.estModerateur == false)
    #expect(DroitsOnglet(profil: horsConseil).cs == false, "le serveur dit non : les rôles n'y changent rien")
    let moderateur = try profil(roles: #"["propriétaire"]"#, #", "est_moderateur": true"#)
    #expect(DroitsOnglet(profil: moderateur).cs == true)
    // `DroitsAffaires.moderateur` n'existe plus (#105) : ce qu'un compte pose dans une affaire
    // se lit dans les référentiels (`permise`) — `poserLesReserveesSeLitDansLesCategoriesServies`.
}

/// Aucun rôle ne remplace `est_moderateur` : non servi, ou d'un profil gardé avant #136,
/// le compte ne modère pas (défaut fermé) jusqu'à la prochaine lecture de `GET /auth/me`.
@Test func sansEstModerateurPersonneNeModere() throws {
    let conseil = try profil(roles: #"["conseil_syndical", "admin"]"#)
    #expect(conseil.estModerateur == false, "non servi : non")
    #expect(DroitsOnglet(profil: conseil).cs == false)
    let garde = ProfilResidence(statut: "copropriétaire_résident", roles: ["conseil_syndical"])
    #expect(garde.estModerateur == nil && DroitsOnglet(profil: garde).cs == false, "un profil gardé avant #136")
}

/// Propriétaire ou conseil : le rôle de propriétaire, ou modérer (`isProprioOuCS` du site).
@Test func proprioOuCSEstLeRoleDeProprietaireOuModerer() throws {
    #expect(DroitsOnglet(profil: try profil(roles: #"["propriétaire"]"#)).proprioOuCS)
    #expect(DroitsOnglet(profil: try profil(roles: #"["résident"]"#, #", "est_moderateur": true"#)).proprioOuCS)
    let conseilSansModerer = ProfilResidence(statut: nil, roles: ["résident", "conseil_syndical"], estModerateur: false)
    #expect(!DroitsOnglet(profil: conseilSansModerer).proprioOuCS, "le rôle seul ne dit pas « modère »")
}

@Test func laCommunauteLitEstModerateurAussi() {
    let moi = MoiCommunaute(
        id: 7, statut: "copropriétaire_résident", roles: ["conseil_syndical"], motifRefus: nil, estModerateur: false)
    #expect(moi.droits.cs == false)
    let modere = MoiCommunaute(id: 7, statut: "", roles: ["résident"], motifRefus: nil, estModerateur: true)
    #expect(modere.droits.cs == true)
}

// MARK: - #138 : l'auteur d'un message, et « le mien »

/// Un message du fil (`MessageRead` des tickets), avec `extra` ajouté tel quel.
private func message(_ extra: String) throws -> MessageAffaire {
    let json =
        #"""
        [{"id": 1, "ticket_id": 41, "auteur_id": 7, "auteur_qualite": "Un résident", "contenu": "<p>Bonjour</p>",
          "interne": false, "cree_le": "2026-11-10T09:00:00"
        """# + extra + "}]"
    return try #require(Relecture.generee([MessageAffaire.Servi].self, json: json).map(MessageAffaire.init).first)
}

@Test func estAuteurServiRangeLaBulleSansComparerLesIdentifiants() throws {
    let mien = try message(#", "auteur_nom": "Jean-Baptiste FORT", "est_auteur": true"#)
    #expect(mien.deMoi && mien.auteur == "Vous")
    let autre = try message(#", "auteur_nom": "Jean-Baptiste FORT", "est_auteur": false"#)
    #expect(!autre.deMoi && autre.auteur == "Jean-Baptiste FORT")
}

@Test func sansNomServiLaBulleDitLaQualite() throws {
    let sansRien = try message("")
    #expect(!sansRien.deMoi && sansRien.auteur == "Un résident", "la qualité servie, à défaut du nom")
    #expect(try message(#", "auteur_nom": """#).auteur == "Un résident")
}
