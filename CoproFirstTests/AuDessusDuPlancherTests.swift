// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

// Le MÉCANISME « au-dessus du plancher » (#89) — `Relecture.auDessusDuPlancher` — et ce
// qu'il a relu jusqu'à la montée du plancher à v3.88.1 (contrat 1.26.0), qui se lit
// désormais par les types générés : gestes de rôle et bannissement (#89), annonce d'une
// demande traitée (#87), niveaux libres d'un périmètre (#88). Plus aucun écran n'emploie
// le mécanisme : il reste, avec ses tests, pour le prochain champ qu'une installation
// servira avant que le plancher ne le type.

// MARK: - Le mécanisme, sur un modèle d'essai

/// Un champ qu'une installation plus récente servirait : tout y est facultatif.
private struct EssaiAuDessusDuPlancher: Decodable, Identifiable, Equatable {
    let id: Int
    var champNeuf: String?
}

@Test func unChampServiAuDessusDuPlancherSeRelitDansLeCorps() {
    let corps = Data(#"{"id": 3, "connu": true, "champ_neuf": "servi"}"#.utf8)
    #expect(
        Relecture.auDessusDuPlancher(EssaiAuDessusDuPlancher.self, corps: corps)
            == EssaiAuDessusDuPlancher(id: 3, champNeuf: "servi"))
    let anterieure = Data(#"{"id": 3, "connu": true}"#.utf8)
    #expect(
        Relecture.auDessusDuPlancher(EssaiAuDessusDuPlancher.self, corps: anterieure)?.champNeuf == nil,
        "installation antérieure : le champ n'est pas servi")
}

@Test func uneListeServieSeRelitParIdentifiant() {
    let corps = Data(#"[{"id": 1, "champ_neuf": "a"}, {"id": 2}, {"id": 1, "champ_neuf": "doublon"}]"#.utf8)
    let lus = Relecture.auDessusDuPlancher(parLigne: EssaiAuDessusDuPlancher.self, corps: corps)
    #expect(lus[1]?.champNeuf == "a", "la première ligne d'un identifiant fait foi")
    #expect(lus[2] == EssaiAuDessusDuPlancher(id: 2, champNeuf: nil))
    #expect(Relecture.auDessusDuPlancher(parLigne: EssaiAuDessusDuPlancher.self, corps: nil).isEmpty)
}

@Test func unCorpsIllisibleNOffreRien() {
    #expect(Relecture.auDessusDuPlancher(EssaiAuDessusDuPlancher.self, corps: Data("<html>".utf8)) == nil)
    #expect(Relecture.auDessusDuPlancher(EssaiAuDessusDuPlancher.self, corps: nil) == nil)
    #expect(Relecture.auDessusDuPlancher(parLigne: EssaiAuDessusDuPlancher.self, corps: Data("{}".utf8)).isEmpty)
}

// MARK: - #89 : gestes de rôle et bannissement, par le type généré

/// Un compte de `UtilisateurAdminRead`, avec ses gestes de rôle et `extra` ajouté tel quel.
private func lu(gestes: String, _ extra: String = "") throws -> UtilisateurAdmin {
    let json =
        #"""
        [{"id": 21, "prenom": "Alex", "nom": "Témoin", "nom_affiche": "Alex TÉMOIN", "nom_aide_affiche": "",
          "email": "alex@exemple.fr", "statut": "copropriétaire_résident", "role": "propriétaire",
          "roles": ["propriétaire"], "actif": true, "has_lots": true, "has_tc": false, "has_vigik": false,
          "has_bail": false,
          "etiquettes": {"loti": "ok", "tc": "sans_objet", "vigik": "sans_objet", "bail": "sans_objet"},
          "onboarding_complete": true, "onboarding_etape": 4, "preferences_notifications": "{}",
          "communaute_ban_jusqu_au": "2099-01-01T00:00:00", "cree_le": "2026-01-01T10:00:00",
          "gestes_roles":
        """# + gestes + extra + "}]"
    let generes = try Relecture.generee([Components.Schemas.UtilisateurAdminRead].self, json: json)
    return try #require(generes.map(UtilisateurAdmin.init).first)
}

@Test func lesGestesDeRoleServisSontOffertsDansLOrdreDuSite() throws {
    let alex = try lu(gestes: #"{"operateur": "ajouter", "admin": "retirer", "conseil_syndical": "ajouter"}"#)
    #expect(alex.gestesRoles.map(\.role) == ["conseil_syndical", "admin", "operateur"])
    #expect(alex.gestesRoles.map(\.geste) == [.ajouter, .retirer, .ajouter])
    #expect(alex.gestesRoles.map(TextesUtilisateursAdmin.bouton) == ["+ CS", "– Admin", "+ Opérateur"])
}

@Test func unGesteNulNEstPasOffert() throws {
    let alex = try lu(gestes: #"{"conseil_syndical": null, "admin": null, "operateur": null}"#)
    #expect(alex.gestesRoles.isEmpty, "servis, mais aucun : rien à offrir (défaut fermé)")
    #expect(try lu(gestes: "{}").gestesRoles.isEmpty)
}

/// Un geste hors du contrat ne s'offre pas : la réponse ne se lit pas (le contrat borne
/// les gestes à `ajouter` et `retirer`).
@Test func unGesteHorsDuContratNeSeLitPas() {
    #expect(throws: (any Error).self) {
        try lu(gestes: #"{"conseil_syndical": null, "admin": "promouvoir", "operateur": null}"#)
    }
}

/// `communaute_banni` fait foi, jamais l'heure du téléphone : le ban court jusqu'en 2099,
/// mais le serveur dit qu'il ne vaut plus.
@Test func leBannissementSeLitTelQueServi() throws {
    let aucun = #"{"conseil_syndical": null, "admin": null, "operateur": null}"#
    #expect(try lu(gestes: aucun, #", "communaute_banni": false"#).ban.banni == false)
    #expect(try lu(gestes: aucun, #", "communaute_banni": true"#).ban.banni == true)
    #expect(try lu(gestes: aucun).ban.banni == false, "non servi : l'app ne compare pas la date à son heure")
}

/// Après un geste, la LISTE se relit ; l'API simulée sert le geste inverse.
@MainActor
@Test func unGesteDeRoleChangeLesRolesEtRelitLaListe() async throws {
    let service = ServiceSimule()
    let etat = EtatUtilisateursAdmin()
    await etat.charger(service, ServiceSimule.residence)
    let alix = try #require(etat.compte(13))
    let ajouterCS = try #require(alix.gestesRoles.first { $0.role == "conseil_syndical" })
    #expect(ajouterCS.geste == .ajouter)
    let annonce = try await etat.changerRole(alix, ajouterCS, service, ServiceSimule.residence)
    #expect(annonce == "Rôle Conseil syndical ajouté à Alix MODÈLE.")
    #expect(etat.compte(13)?.roles.contains("conseil_syndical") == true)
    #expect(etat.compte(13)?.gestesRoles.first?.geste == .retirer)
    #expect(etat.membresDuConseil == 2)
}

/// Un compte inactif n'a aucun geste ; le seul administrateur ne perd pas son rôle.
@Test func lesGestesSimulesSontCeuxDuServeur() throws {
    let comptes = try FixturesUtilisateursAdmin.lus()
    #expect(comptes.first { $0.id == 14 }?.gestesRoles == [])
    #expect(comptes.first { $0.id == 11 }?.gestesRoles.contains { $0.role == "admin" } == false)
}

// MARK: - #87 : l'annonce d'une demande traitée, par son type généré

@Test func lAnnonceDuTraitementSeLitTelleQueServie() throws {
    let servie = try Relecture.generee(
        Components.Schemas.DemandeProfilTraitee.self,
        json: #"{"statut": "rejetee", "annonce": {"ton": "warning", "texte": "Phrase du serveur."}}"#)
    #expect(PhraseAvis(servie.annonce) == PhraseAvis(texte: "Phrase du serveur.", ton: .warning))
    // Sans annonce, la réponse n'est pas celle du contrat : elle ne se lit pas, l'app ne
    // compose pas de phrase à sa place.
    #expect(throws: (any Error).self) {
        try Relecture.generee(Components.Schemas.DemandeProfilTraitee.self, json: #"{"statut": "approuvee"}"#)
    }
}

@MainActor
@Test func leTraitementDitLAnnonceServie() async throws {
    let etat = EtatDemandesProfil()
    let service = ServiceSimule()
    await etat.charger(service, ServiceSimule.residence)
    let demande = try #require(etat.demandes.first)
    let servie = try await etat.traiter(demande, approuver: false, motif: nil, service, ServiceSimule.residence)
    #expect(servie == PhraseAvis(texte: "Demande rejetée.", ton: .success))
    #expect(!etat.demandes.contains { $0.id == demande.id })
}

// MARK: - #88 : le sélecteur de périmètre descend jusqu'au niveau 3

@Test func leSelecteurProposeLeNiveauTroisEtJamaisPlusBas() throws {
    let codes = Perimetre.aSaisir(try FixturesPerimetres.lus()).map(\.code)
    #expect(codes.contains("bat_a_terrasses"), "niveau 3")
    #expect(!codes.contains("bat_a_terrasse_nord"), "niveau 4, écrit avant le plafond")
    #expect(codes.first == "copropriete")
    let modifiee = Perimetre.aSaisir(try FixturesPerimetres.lus(), garder: "bat_a_terrasse_nord").map(\.code)
    #expect(modifiee.contains("bat_a_terrasse_nord"), "le lieu déjà enregistré d'une affaire modifiée reste proposé")
}

/// `niveaux_libres` n'est pas requis par le contrat : un nœud qui ne le dit pas ne limite
/// rien — tout nœud sélectionnable se propose, un regroupement jamais.
@Test func sansNiveauxServisToutNoeudSelectionnableSePropose() throws {
    let sansNiveaux = try FixturesPerimetres.lus().map {
        Perimetre(code: $0.code, libelle: $0.libelle, selectionnable: $0.selectionnable, parent: $0.parent)
    }
    #expect(Perimetre.aSaisir(sansNiveaux).count == sansNiveaux.filter(\.selectionnable).count)
    let regroupement = [Perimetre(code: "batiments", libelle: "Bâtiments", selectionnable: false)]
    #expect(Perimetre.aSaisir(regroupement).isEmpty)
}
