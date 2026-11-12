// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Testing

@testable import CoproFirst

/// Les onglets qu'un compte ouvre (#29) — la règle d'`ongletsOuverts` du site, sur les
/// onglets GÉNÉRÉS depuis `pages.ts`. Un compte par rôle de la démo, puis les cas
/// d'exception (administration, opération, gestion).
private func ouverts(_ page: String, _ droits: DroitsOnglet) -> [String] {
    OngletsDuSite.ouverts(page: page, droits: droits).map(\.id)
}

private let conseilSyndical = DroitsOnglet(
    roles: ["conseil_syndical", "propriétaire"], role: "propriétaire", statut: "copropriétaire_résident",
    estModerateur: true)
private let coproprietaire = DroitsOnglet(
    roles: ["propriétaire"], role: "propriétaire", statut: "copropriétaire_bailleur")
private let locataire = DroitsOnglet(roles: ["résident"], role: "résident", statut: "locataire")

@Test func lesDroitsSeLisentCommeLeSite() {
    #expect(conseilSyndical == DroitsOnglet(proprioOuCS: true, cs: true))
    #expect(coproprietaire == DroitsOnglet(proprioOuCS: true))
    #expect(locataire == DroitsOnglet(locataire: true))
    #expect(DroitsOnglet(roles: [], role: "admin", statut: nil).administrateur, "`role` seul quand `roles` est vide")
    #expect(DroitsOnglet(roles: [], role: nil, statut: "syndic").gestionnaire)
    // « Modère » est SERVI (`est_moderateur`) : aucun rôle n'en décide, pas même « admin ».
    #expect(!DroitsOnglet(roles: ["admin", "conseil_syndical"], role: "admin", statut: nil).cs)
    #expect(DroitsOnglet(roles: ["résident"], role: "résident", statut: nil, estModerateur: true).cs)
    #expect(!coproprietaire.cs)
    #expect(OngletsDuSite.rolesProprietaire == ["propriétaire"], "`ROLES_DU_DROIT.proprietaire` du site")
    // Propriétaire ou conseil : le rôle, ou modérer (`isProprioOuCS` du site).
    #expect(DroitsOnglet(roles: ["résident"], role: "résident", statut: nil, estModerateur: true).proprioOuCS)
    #expect(!DroitsOnglet(roles: ["résident", "conseil_syndical"], role: "résident", statut: nil).proprioOuCS)
}

@Test func leLocataireNeVoitNiCarnetNiReglementNiKanban() {
    #expect(ouverts("residence", locataire) == ["fiche"])
    #expect(ouverts("mes-demandes", locataire) == ["liste", "archives"])
    #expect(ouverts("communaute", locataire) == ["sondages", "idees", "annonces", "avis"])
}

@Test func leCoproprietaireEtLeConseilVoientToutLeResident() {
    for droits in [coproprietaire, conseilSyndical] {
        #expect(ouverts("residence", droits) == ["fiche", "carnet", "reglement"])
        #expect(ouverts("mes-demandes", droits) == ["liste", "kanban", "archives"])
    }
}

@Test func leGestionnaireNOuvrePasLaCommunaute() {
    let syndic = DroitsOnglet(roles: ["externe"], role: "externe", statut: "syndic")
    #expect(ouverts("communaute", syndic) == ["avis"])
}

@Test func lAdministrationSOuvreALAdministrateurEtEnPartieALOperateur() {
    let admin = DroitsOnglet(roles: ["admin"], role: "admin", statut: nil)
    let operateur = DroitsOnglet(roles: ["operateur"], role: "operateur", statut: nil)
    let tous = OngletsDuSite.parPage["admin"] ?? []
    #expect(ouverts("admin", admin) == tous.filter { $0.reserve != .operateur }.map(\.id))
    #expect(ouverts("admin", operateur) == tous.filter(\.ouvertOperateur).map(\.id))
    #expect(!ouverts("admin", operateur).isEmpty)
    #expect(ouverts("admin", conseilSyndical).isEmpty, "le conseil syndical n'ouvre pas l'administration")
}

@Test func unePageSansOngletsOuInconnueNOuvreRien() {
    #expect(ouverts("annuaire", conseilSyndical).isEmpty)
    #expect(ouverts("inconnue", conseilSyndical).isEmpty)
}

/// La table générée suit le site : les réserves posées sur les onglets connus.
@Test func lesReservesGenereesSontCellesDuSite() {
    let reserve = { (page: String, id: String) in OngletsDuSite.parPage[page]?.first { $0.id == id }?.reserve }
    #expect(reserve("residence", "carnet") == .proprioOuCS)
    #expect(reserve("mes-demandes", "kanban") == .nonLocataire)
    #expect(reserve("communaute", "annonces") == .nonGestionnaire)
    #expect(reserve("residence", "fiche") == nil)
    #expect(OngletsDuSite.parPage["mes-demandes"]?.last?.libelle == "Archives", "la constante TITRE_ARCHIVES est lue")
}
