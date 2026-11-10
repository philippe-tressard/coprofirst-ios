// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

// Ce que le serveur sert au-dessus du plancher, relu sans rien recomposer (#87, #88, #89) :
// chaque champ, servi puis absent (installation antérieure : le comportement d'avant).

/// Un compte de `UtilisateurAdminRead`, avec `extra` ajouté tel quel au JSON servi.
private func compte(_ extra: String) -> String {
    #"""
    [{"id": 21, "prenom": "Alex", "nom": "Témoin", "email": "alex@exemple.fr",
      "statut": "copropriétaire_résident", "role": "propriétaire", "roles": ["propriétaire"], "actif": true,
      "has_lots": true, "has_tc": false, "has_vigik": false, "has_bail": false,
      "etiquettes": {"loti": "ok", "tc": "sans_objet", "vigik": "sans_objet", "bail": "sans_objet"},
      "onboarding_complete": true, "onboarding_etape": 4, "preferences_notifications": "{}",
      "communaute_ban_jusqu_au": "2099-01-01T00:00:00", "cree_le": "2026-01-01T10:00:00"
    """# + extra + "}]"
}

private func lu(_ extra: String) throws -> UtilisateurAdmin {
    let json = compte(extra)
    let generes = try Relecture.generee([Components.Schemas.UtilisateurAdminRead].self, json: json)
    return try #require(UtilisateurAdmin.lus(generes, corps: Data(json.utf8)).first)
}

// MARK: - #89 : gestes de rôle et bannissement servis

@Test func lesGestesDeRoleServisSontOffertsDansLOrdreDuSite() throws {
    let alex = try lu(#", "gestes_roles": {"operateur": "ajouter", "admin": "retirer", "conseil_syndical": "ajouter"}"#)
    #expect(alex.gestesRoles?.map(\.role) == ["conseil_syndical", "admin", "operateur"])
    #expect(alex.gestesRoles?.map(\.geste) == [.ajouter, .retirer, .ajouter])
    #expect(alex.gestesRoles.map { $0.map(TextesUtilisateursAdmin.bouton) } == ["+ CS", "– Admin", "+ Opérateur"])
}

@Test func unGesteNulOuInconnuNEstPasOffert() throws {
    let alex = try lu(#", "gestes_roles": {"conseil_syndical": null, "admin": "promouvoir", "operateur": null}"#)
    #expect(alex.gestesRoles == [], "servis, mais aucun : rien à offrir (défaut fermé)")
}

@Test func sansGestesServisLesRolesRestentAuSite() throws {
    let alex = try lu("")
    #expect(alex.gestesRoles == nil, "installation antérieure au contrat 1.18.0")
}

/// `communaute_banni` prime sur l'heure du téléphone : le ban court jusqu'en 2099, mais
/// le serveur dit qu'il ne vaut plus.
@Test func leBannissementSeLitTelQueServi() throws {
    #expect(try lu(#", "communaute_banni": false"#).ban.banni() == false)
    #expect(try lu(#", "communaute_banni": true"#).ban.banni() == true)
    #expect(try lu("").ban.banni() == true, "non servi : la date, à l'heure du téléphone, comme avant")
}

@Test func unCorpsIllisibleNOffreRien() {
    #expect(Relecture.auDessusDuPlancher(UtilisateurAuDessusDuPlancher.self, corps: Data("<html>".utf8)) == nil)
    #expect(Relecture.auDessusDuPlancher(UtilisateurAuDessusDuPlancher.self, corps: nil) == nil)
}

/// Après un geste, la LISTE se relit ; l'API simulée sert le geste inverse.
@MainActor
@Test func unGesteDeRoleChangeLesRolesEtRelitLaListe() async throws {
    let service = ServiceSimule()
    let etat = EtatUtilisateursAdmin()
    await etat.charger(service, ServiceSimule.residence)
    let alix = try #require(etat.compte(13))
    let ajouterCS = try #require(alix.gestesRoles?.first { $0.role == "conseil_syndical" })
    #expect(ajouterCS.geste == .ajouter)
    let annonce = try await etat.changerRole(alix, ajouterCS, service, ServiceSimule.residence)
    #expect(annonce == "Rôle Conseil syndical ajouté à Alix Modèle.")
    #expect(etat.compte(13)?.roles.contains("conseil_syndical") == true)
    #expect(etat.compte(13)?.gestesRoles?.first?.geste == .retirer)
    #expect(etat.membresDuConseil == 2)
}

/// Un compte inactif n'a aucun geste ; le seul administrateur ne perd pas son rôle.
@Test func lesGestesSimulesSontCeuxDuServeur() throws {
    let comptes = try FixturesUtilisateursAdmin.lus()
    #expect(comptes.first { $0.id == 14 }?.gestesRoles == [])
    #expect(comptes.first { $0.id == 11 }?.gestesRoles?.contains { $0.role == "admin" } == false)
}

// MARK: - #87 : l'annonce d'une demande traitée

@Test func lAnnonceDuTraitementSeLitTelleQueServie() throws {
    let servie = ReponseNonTypee(
        nom: "v3.81", route: "POST /admin/demandes-profil/{demande_id}/traiter",
        json: #"{"statut": "rejetee", "annonce": {"ton": "warning", "texte": "Phrase du serveur."}}"#)
    #expect(try servie.lire(DemandeProfilTraitee.self).phrase == PhraseAvis(texte: "Phrase du serveur.", ton: .warning))
    let ancienne = ReponseNonTypee(
        nom: "v3.73", route: "POST /admin/demandes-profil/{demande_id}/traiter", json: #"{"statut": "approuvee"}"#)
    #expect(try ancienne.lire(DemandeProfilTraitee.self).phrase == nil)
}

/// Un serveur antérieur au contrat 1.16.0 ne sert pas d'annonce : la phrase d'avant.
private struct DemandesSansAnnonce: ServiceDemandesProfil {
    func demandesProfil(_ installation: Installation) async throws -> [DemandeProfil] { [] }
    func traiterDemandeProfil(
        _ id: Int, approuver: Bool, motif: String?, dans installation: Installation
    ) async throws -> PhraseAvis? { nil }
}

@MainActor
@Test func leTraitementDitLAnnonceServieSinonLaPhraseDAvant() async throws {
    let etat = EtatDemandesProfil()
    let service = ServiceSimule()
    await etat.charger(service, ServiceSimule.residence)
    let demande = try #require(etat.demandes.first)
    let servie = try await etat.traiter(demande, approuver: false, motif: nil, service, ServiceSimule.residence)
    #expect(servie == PhraseAvis(texte: "Demande rejetée.", ton: .success))
    #expect(!etat.demandes.contains { $0.id == demande.id })
    let ancienne = try await etat.traiter(
        demande, approuver: true, motif: nil, DemandesSansAnnonce(), ServiceSimule.residence)
    #expect(ancienne == PhraseAvis(texte: TextesATraiter.approuvee))
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

@Test func sansNiveauxServisToutNoeudSelectionnableSePropose() throws {
    let anciens = try FixturesPerimetres.lus().map {
        Perimetre(code: $0.code, libelle: $0.libelle, selectionnable: $0.selectionnable, parent: $0.parent)
    }
    #expect(Perimetre.aSaisir(anciens).count == anciens.count, "installation antérieure au contrat 1.17.0")
    let regroupement = [Perimetre(code: "batiments", libelle: "Bâtiments", selectionnable: false)]
    #expect(Perimetre.aSaisir(regroupement).isEmpty)
}
