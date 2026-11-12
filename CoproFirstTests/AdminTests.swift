// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

// Le Paramétrage, en partie (#16) : qui l'ouvre, quels onglets, ce qui renvoie au site,
// et ce que lisent les quatre onglets de l'app.

/// `modere` : ce que le serveur sert (`est_moderateur`) — aucun rôle ne le dit.
private func droits(_ roles: [String], statut: String? = nil, modere: Bool = false) -> DroitsOnglet {
    DroitsOnglet(roles: roles, role: nil, statut: statut, estModerateur: modere)
}

// MARK: - Le cadre et ses onglets

@MainActor
@Test func leParametrageEstInscrit() {
    #expect(RegistreDesMenus.ecrans["admin"] == AdminView.self)
    let duSite = Set((OngletsDuSite.parPage["admin"] ?? []).map(\.id))
    for id in OngletsAdmin.ecrans.keys {
        #expect(duSite.contains(id), "« \(id) » : inconnu de la page admin")
    }
    #expect(Set(OngletsAdmin.ecrans.keys) == ["a_traiter", "utilisateurs", "telemetry", "maintenance"])
}

@Test func lAdministrateurEtLOperateurOuvrentLeParametrage() {
    #expect(PagesOuvertes.ouverte("admin", droits: droits(["propriétaire", "admin"], modere: true)))
    #expect(PagesOuvertes.ouverte("admin", droits: droits(["operateur"], statut: "admin_technique")))
    #expect(!PagesOuvertes.ouverte("admin", droits: droits(["propriétaire", "conseil_syndical"], modere: true)))
}

/// L'opérateur qui n'est pas administrateur n'ouvre que l'Exploitation : dans l'app, la
/// Maintenance — et « Sur le site » pour les deux autres.
@Test func lOperateurNOuvreQueLExploitation() {
    let ouverts = OngletsDuSite.ouverts(page: "admin", droits: droits(["operateur"], statut: "admin_technique"))
    #expect(ouverts.map(\.id) == ["installation", "maintenance", "installations"])
}

/// Chaque onglet a son adresse sur le site — « Sur le site » en fait un lien.
@Test func chaqueOngletDuParametrageASonAdresse() {
    for onglet in OngletsDuSite.parPage["admin"] ?? [] {
        #expect(TablesAdmin.routes[onglet.id] != nil, "« \(onglet.id) » sans adresse")
    }
}

@Test(arguments: [
    ("https://demo.coprofirst.fr", "https://demo.coprofirst.fr/admin?onglet=imports"),
    ("https://demo.coprofirst.fr/", "https://demo.coprofirst.fr/admin?onglet=imports"),
    ("https://exemple.fr/copro", "https://exemple.fr/copro/admin?onglet=imports"),
])
func unOngletDuSiteSOuvreSousLAdresseDeLaResidence(adresse: String, attendu: String) throws {
    let base = try #require(URL(string: adresse))
    #expect(OngletSurLeSite.lien("/admin?onglet=imports", sur: base)?.absoluteString == attendu)
}

// MARK: - Les services : aucun `nil` silencieux

@Test func lesDeuxServicesPortentLesQuatreOnglets() {
    let _: any ServiceDemandesProfil = ServiceAPI()
    let _: any ServiceDemandesProfil = ServiceSimule()
    let _: any ServiceUtilisateursAdmin = ServiceAPI()
    let _: any ServiceUtilisateursAdmin = ServiceSimule()
    let _: any ServiceTelemetrie = ServiceAPI()
    let _: any ServiceTelemetrie = ServiceSimule()
    let _: any ServiceMaintenance = ServiceAPI()
    let _: any ServiceMaintenance = ServiceSimule()
}

// MARK: - Les lectures (le JSON des routes, par le même chemin que le service réel)

@Test func lesDemandesDeProfilSeLisent() throws {
    let demandes = try FixturesDemandesProfil.lues()
    #expect(demandes.map(\.id) == [41, 42])
    #expect(demandes[0].statutSouhaite == "copropriétaire_bailleur")
    #expect(demandes[1].batimentNomSouhaite == "Bâtiment B")
    #expect(demandes[0].utilisateurNom == "Sacha Exemple")
}

@Test(arguments: PorteeTelemetrie.allCases)
func chaqueVueDeLaTelemetrieSeLit(portee: PorteeTelemetrie) throws {
    let tableau = try FixturesTelemetrie.tableau(portee)
    #expect(tableau.scope == portee.rawValue)
    #expect(!tableau.chart.isEmpty)
    #expect(!TextesTelemetrie.indicateurs(tableau.kpi, portee).isEmpty)
}

@Test func lesEtiquettesDuGrapheSontCellesDuSite() {
    #expect(TextesTelemetrie.etiquette("18h", .jour) == "18h")
    #expect(TextesTelemetrie.etiquette("11-04", .mois) == "4")
    #expect(TextesTelemetrie.libelle("11-04", .mois) == "4 nov.")
    #expect(TextesTelemetrie.etiquette("2026-11", .annee) == "nov.")
    #expect(TextesTelemetrie.libelle("2026-11", .annee) == "novembre 2026")
    #expect(TextesTelemetrie.etiquette("2025", .total) == "2025")
}

@Test func laSanteDesTachesSeLitEtSeNommeParLeSite() throws {
    let sante = try FixturesMaintenance.santeLue()
    #expect(sante.anomaliesFenetreJours == 7)
    let bascule = try #require(sante.taches.first { $0.tache == "bascule" })
    #expect(bascule.noeudEnRetard == "nœud-b")
    for tache in sante.taches {
        #expect(TablesAdmin.libellesTache[tache.tache] != nil, "« \(tache.tache) » sans nom")
        #expect(TablesAdmin.libellesStatut[tache.statut] != nil, "« \(tache.statut) » sans libellé")
        #expect(TablesAdmin.teintesStatut[tache.statut]?.hasPrefix("badge-") == true)
    }
}

@Test func leDernierExportSeDit() throws {
    let export = try FixturesMaintenance.dernierExportLu()
    #expect(TextesMaintenance.dernierExport(export).contains("46,0 Mo"))
    let aucun = DernierExport(archive: nil, creeLe: nil, octets: 0, tables: 0, lignes: 0, fichiers: 0)
    #expect(TextesMaintenance.dernierExport(aucun) == "Aucun export dans le volume des sauvegardes.")
}

// MARK: - Utilisateurs

@MainActor
@Test func lesUtilisateursSeFiltrentEtSeTrientCommeSurLeSite() async throws {
    let etat = EtatUtilisateursAdmin()
    await etat.charger(ServiceSimule(), ServiceSimule.residence)
    #expect(etat.affiches.map(\.id) == [11, 12, 14, 13, 15], "par nom, puis prénom")
    etat.recherche = "dominique"
    #expect(etat.affiches.map(\.id) == [12])
    etat.recherche = ""
    etat.compte = .enAttente
    #expect(etat.affiches.map(\.id) == [14])
    etat.compte = .tous
    etat.statut = "locataire"
    #expect(etat.affiches.map(\.id) == [12])
    #expect(etat.membresDuConseil == 1)
}

/// Le ban de Dominique court jusqu'au 05/12/2026 et le serveur le dit banni ; l'app ne
/// compare pas la date à son heure (`communaute_banni`, jugé à l'heure du serveur).
@Test func leBannissementDesComptesSimulesEstCeluiQueLeServeurDit() throws {
    let comptes = try FixturesUtilisateursAdmin.lus()
    let dominique = try #require(comptes.first { $0.id == 12 })
    #expect(dominique.ban.banni && dominique.ban.jusquAu != nil && !dominique.ban.interdit)
    #expect(comptes.filter { $0.id != 12 }.allSatisfy { !$0.ban.banni })
}

/// Le premier bannissement simulé est probatoire, le suivant définitif — comme le serveur.
@MainActor
@Test func bannirPuisReautoriserChangeLaListe() async throws {
    let service = ServiceSimule()
    let etat = EtatUtilisateursAdmin()
    await etat.charger(service, ServiceSimule.residence)
    let alix = try #require(etat.compte(13))
    #expect(try await etat.basculerCommunaute(alix, service, ServiceSimule.residence).contains("1 mois"))
    #expect(etat.compte(13)?.ban.banni == true)
    let banni = try #require(etat.compte(13))
    #expect(try await etat.basculerCommunaute(banni, service, ServiceSimule.residence).contains("réautorisé"))
    #expect(etat.compte(13)?.ban.banni == false)
}
