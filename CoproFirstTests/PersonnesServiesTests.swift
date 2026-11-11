// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

// Ce que le serveur dit d'une PERSONNE, lu au lieu d'être recomposé (coprofirst#2633,
// #2680) : le nom affiché (#135, contrat 1.25.0), « modère » (#136, 1.25.0), l'auteur d'un
// message et « le mien » (#138, 1.26.0). Chaque champ servi, puis absent : une
// installation antérieure garde le comportement d'avant, écrit en UN endroit.

/// Un compte `UserRead` au plancher, avec `extra` ajouté tel quel au JSON servi.
private func compte(_ id: Int, roles: String, _ extra: String = "") -> String {
    #"""
    {"id": \#(id), "prenom": "Jean-Baptiste", "nom": "Fort", "email": "jb@exemple.fr",
     "statut": "copropriétaire_résident", "role": "propriétaire", "roles": \#(roles), "actif": true,
     "onboarding_complete": true, "onboarding_etape": 4, "preferences_notifications": "{}",
     "cree_le": "2026-01-01T10:00:00"
    """# + extra + "}"
}

private func profil(roles: String, _ extra: String = "") throws -> ProfilResidence {
    let json = compte(5, roles: roles, extra)
    return ProfilResidence(try Relecture.generee(Components.Schemas.UserRead.self, json: json), corps: Data(json.utf8))
}

// MARK: - #135 : le nom affiché

@Test func leNomServiPrimeEtLeRepliNeVitQuEnUnEndroit() {
    let servi = "Jean-Baptiste FORT"
    #expect(FormatsDuSite.nom(affiche: servi, prenom: "Jean-Baptiste", nom: "Fort") == servi)
    #expect(FormatsDuSite.nom(affiche: nil, prenom: "Jean-Baptiste", nom: "Fort") == "Jean-Baptiste Fort")
    #expect(FormatsDuSite.nom(affiche: "  ", prenom: "Jean-Baptiste", nom: nil) == "Jean-Baptiste", "servi vide")
    #expect(FormatsDuSite.nom(affiche: "", prenom: nil, nom: nil) == FormatsDuSite.tiret)
}

private func compteDuProfil(_ json: String) throws -> Compte {
    Compte(lu: try Relecture.generee(Components.Schemas.UserRead.self, json: json), corps: Data(json.utf8))
}

@Test func leCompteDuProfilSeNommeParLeServeur() throws {
    let servi = try compteDuProfil(compte(5, roles: "[]", #", "nom_affiche": "Jean-Baptiste FORT""#))
    #expect(servi.nomAffiche == "Jean-Baptiste FORT")
    let avant = try compteDuProfil(compte(5, roles: "[]"))
    #expect(avant.nomAffiche == "Jean-Baptiste Fort", "installation antérieure au contrat 1.25.0")
}

@Test func laFileDesComptesNommeLeCompteEtLaPersonneAidee() throws {
    let comptes = try FixturesComptesCS.comptesLus()
    #expect(comptes.map(\.nomAffiche) == ["Camille EXEMPLE", "Dominique FICTIF", "Alix MODÈLE"])
    #expect(comptes.map(\.nomAideAffiche) == [nil, nil, "Claude FICTIF"])
    let generes = try Relecture.generee([Components.Schemas.UserRead].self, json: FixturesComptesCS.comptes)
    let avant = CompteEnAttente.lus(generes, corps: nil)
    #expect(avant.map(\.nomAffiche) == ["Camille Exemple", "Dominique Fictif", "Alix Modèle"])
    #expect(avant.last?.nomAideAffiche == "Claude Fictif")
}

@Test func lesComptesDeLAdministrationEtDesDelegationsSeNommentParLeServeur() throws {
    #expect(try FixturesUtilisateursAdmin.lus().first { $0.id == 13 }?.nomAffiche == "Alix MODÈLE")
    #expect(try FixturesDelegations.residentsLus().first { $0.id == 4 }?.nomAffiche == "Marc DÉMO")
    let generes = try Relecture.generee(
        [Components.Schemas.UtilisateurAdminRead].self, json: FixturesUtilisateursAdmin.utilisateurs)
    #expect(UtilisateurAdmin.lus(generes, corps: nil).first { $0.id == 13 }?.nomAffiche == "Alix Modèle")
}

@Test func unBailNommeSonLocataireEtSonBailleurParLeServeur() throws {
    let baux = try FixturesAcces.bauxLus()
    #expect(baux.first { $0.id == 3 }?.nomLocataire == "Locataire DU LOT 31")
    let generes = try Relecture.generee([Components.Schemas.BailOut].self, json: FixturesAcces.baux)
    #expect(Bail.lus(generes, corps: nil).first { $0.id == 3 }?.nomLocataire == "Locataire du lot 31")

    let monBail = #"""
        {"id": 3, "lot_id": 31, "bailleur_nom": "Fort", "bailleur_prenom": "Jean-Baptiste",
         "bailleur_email": null, "bailleur_telephone": null, "date_entree": "2025-09-01",
         "date_sortie_prevue": null, "statut": "actif", "bailleur_nom_affiche": "Jean-Baptiste FORT"}
        """#
    let lu = try Relecture.generee(Components.Schemas.BailLocataireOut.self, json: monBail)
    #expect(BailDuLocataire(lu, corps: Data(monBail.utf8)).nomBailleur == "Jean-Baptiste FORT")
    #expect(BailDuLocataire(lu, corps: nil).nomBailleur == "Jean-Baptiste Fort")
}

@Test func lesContactsDUnPrestataireSeNommentParLeServeurDansLOrdreServi() throws {
    let servi = #"""
        [{"id": 8, "nom": "Ascenseurs Exemple", "specialite": "ascenseur", "actif": true,
          "contacts": [
            {"prenom": "Jean-Baptiste", "nom": "Fort", "fonction": "Technicien", "telephone": "01", "email": null,
             "nom_affiche": "Jean-Baptiste FORT"},
            {"prenom": null, "nom": null, "fonction": "Astreinte", "telephone": "02", "email": null, "nom_affiche": ""}
          ]}]
        """#
    let generes = try Relecture.generee([Components.Schemas.PrestataireRead].self, json: servi)
    let contacts = try #require(Prestataire.lus(generes, corps: Data(servi.utf8)).first).contacts
    #expect(contacts.map(\.nomAffiche) == ["Jean-Baptiste FORT", nil], "sans nom : rien, comme avant")
    #expect(Prestataire.lus(generes, corps: nil).first?.contacts.first?.nomAffiche == "Jean-Baptiste Fort")
}

@Test func lAnnuaireDitLaCiviliteEtLeNomServi() {
    let membre = Annuaire.Membre(
        id: 1, genre: "M.", prenom: "Jean-Baptiste", nom: "Fort", nomServi: "Jean-Baptiste FORT")
    #expect(membre.nomComplet == "M. Jean-Baptiste FORT")
    let gardeAvant = Annuaire.Membre(id: 1, genre: "M.", prenom: "Jean-Baptiste", nom: "Fort")
    #expect(gardeAvant.nomComplet == "M. Jean-Baptiste Fort", "un annuaire gardé avant #135")
}

/// Une fiche du conseil en cours de saisie n'a plus de nom servi : la saisie se nomme par
/// le repli jusqu'à l'enregistrement (`POST /noms/affiche` n'est pas au client du plancher).
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
    #expect(DroitsAffaires(profil: moderateur).moderateur == true)
}

@Test func sansEstModerateurLesRolesDecidentCommeAvant() throws {
    let conseil = try profil(roles: #"["conseil_syndical"]"#)
    #expect(conseil.estModerateur == nil, "installation antérieure au contrat 1.25.0")
    #expect(DroitsOnglet(profil: conseil).cs == true)
    #expect(DroitsOnglet(profil: try profil(roles: #"["propriétaire"]"#)).cs == false)
    let lu = try Relecture.generee(Components.Schemas.UserRead.self, json: compte(5, roles: "[]"))
    let illisible = ProfilResidence(lu, corps: Data("<html>".utf8))
    #expect(illisible.estModerateur == nil, "un corps illisible n'annonce rien")
}

@Test func laCommunauteLitEstModerateurAussi() {
    let moi = MoiCommunaute(
        id: 7, statut: "copropriétaire_résident", roles: ["conseil_syndical"], motifRefus: nil, estModerateur: false)
    #expect(moi.droits.cs == false)
    #expect(MoiCommunaute(id: 7, statut: "", roles: ["conseil_syndical"], motifRefus: nil).droits.cs == true)
}

// MARK: - #138 : l'auteur d'un message, et « le mien »

/// Un message du fil (`MessageRead` des tickets), avec `extra` ajouté tel quel.
private func messages(_ extra: String) -> String {
    #"""
    [{"id": 1, "ticket_id": 41, "auteur_id": 7, "auteur_qualite": "Un résident", "contenu": "<p>Bonjour</p>",
      "interne": false, "cree_le": "2026-11-10T09:00:00"
    """# + extra + "}]"
}

private func message(_ extra: String, moi: Int?, servi: Bool = true) throws -> MessageAffaire {
    let json = messages(extra)
    let generes = try Relecture.generee([MessageAffaire.Servi].self, json: json)
    return try #require(MessageAffaire.lus(generes, corps: servi ? Data(json.utf8) : nil, moi: moi).first)
}

@Test func estAuteurServiRangeLaBulleSansComparerLesIdentifiants() throws {
    let mien = try message(#", "auteur_nom": "Jean-Baptiste FORT", "est_auteur": true"#, moi: 99)
    #expect(mien.deMoi && mien.auteur == "Vous", "le serveur dit « le vôtre » : auteur_id n'y change rien")
    let autre = try message(#", "auteur_nom": "Jean-Baptiste FORT", "est_auteur": false"#, moi: 7)
    #expect(!autre.deMoi, "même identifiant, mais le serveur dit non")
    #expect(autre.auteur == "Jean-Baptiste FORT")
}

@Test func sansChampsServisLaBulleGardeSonRepli() throws {
    let avant = try message("", moi: 7, servi: false)
    #expect(avant.deMoi, "installation antérieure au contrat 1.26.0 : l'identifiant du compte")
    let autre = try message("", moi: 3)
    #expect(!autre.deMoi && autre.auteur == "Un résident", "la qualité servie, à défaut du nom")
    #expect(try message(#", "auteur_nom": """#, moi: 3).auteur == "Un résident")
}
