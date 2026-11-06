// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

// L'Espace conseil syndical (#15) : qui le voit, son cadre, ses trois premiers
// onglets — services, relectures, gestes.

// MARK: - Qui voit l'Espace CS (la barre du site, `Nav.svelte`)

private func droits(_ roles: [String], statut: String? = nil) -> DroitsOnglet {
    DroitsOnglet(roles: roles, role: nil, statut: statut)
}

private let toutes = PagesParDefaut.toutes

@Test func leConseilVoitLEspaceCSEtLesPrestataires() {
    let ids = PagesOuvertes.filtrer(toutes, droits: droits(["résident", "propriétaire", "conseil_syndical"])).map(\.id)
    #expect(ids.contains("espace-cs"))
    #expect(ids.contains("prestataires"))
    #expect(!ids.contains("admin"), "un membre du conseil n'est pas administrateur")
}

@Test func unResidentNeVoitNiLEspaceCSNiLesPrestataires() {
    let ids = PagesOuvertes.filtrer(toutes, droits: droits(["résident", "propriétaire"])).map(\.id)
    #expect(!ids.contains("espace-cs"))
    #expect(!ids.contains("prestataires"))
    #expect(!ids.contains("delegations"))
    #expect(ids.contains("mon-lot"), "les pages des résidents restent ouvertes")
}

@Test func leCompteTechniqueNAPasLesOutilsDuConseil() {
    let technique = droits(["admin"])
    #expect(technique.adminSeul)
    #expect(technique.cs, "`$isCS` inclut l'administrateur…")
    #expect(!PagesOuvertes.ouverte("espace-cs", droits: technique), "…mais pas le compte technique")
    #expect(PagesOuvertes.ouverte("admin", droits: technique))
}

@Test func unAdministrateurCoproprietaireALEspaceCS() {
    let admin = droits(["propriétaire", "admin"])
    #expect(!admin.adminSeul)
    #expect(PagesOuvertes.ouverte("espace-cs", droits: admin))
    #expect(PagesOuvertes.ouverte("admin", droits: admin))
}

@Test func lOperateurOuvreLAdministration() {
    #expect(PagesOuvertes.ouverte("admin", droits: droits(["operateur"])))
    #expect(!PagesOuvertes.ouverte("espace-cs", droits: droits(["operateur"])))
}

@Test func sansProfilLesPagesReserveesSeFerment() {
    let rien = DroitsOnglet(profil: nil)
    let ids = PagesOuvertes.filtrer(toutes, droits: rien).map(\.id)
    #expect(!ids.contains("espace-cs"))
    #expect(ids.contains(OrdrePages.idFil))
}

/// Les pages réservées viennent de `PAGES_ROLES`, après celles de `PAGES` (générées).
@Test func lesPagesReserveesFermentLaBarre() {
    let ids = toutes.map(\.id)
    #expect(Array(ids.suffix(3)) == ["espace-cs", "admin", "delegations"])
}

// MARK: - Le cadre

@MainActor
@Test func lEspaceCSEstInscrit() {
    #expect(RegistreDesMenus.ecrans["espace-cs"] == EspaceCSView.self)
}

/// Chaque onglet inscrit est un onglet du site : un identifiant faux ne s'afficherait
/// jamais (la barre suit `OngletsDuSite`).
@MainActor
@Test func chaqueOngletInscritEstUnOngletDuSite() {
    let duSite = Set((OngletsDuSite.parPage["espace-cs"] ?? []).map(\.id))
    #expect(!duSite.isEmpty)
    for id in OngletsEspaceCS.ecrans.keys {
        #expect(duSite.contains(id), "« \(id) » : inconnu de la page espace-cs")
    }
    #expect(OngletsEspaceCS.ecrans["validations"] == OngletComptesCS.self)
    #expect(OngletsEspaceCS.ecrans["badges"] == OngletBadgesCS.self)
    #expect(OngletsEspaceCS.ecrans["annuaire"] == OngletAnnuaireCS.self)
}

@Test func lesOngletsSuiventLOrdreDuSite() {
    let ids = OngletsDuSite.ouverts(page: "espace-cs", droits: droits(["conseil_syndical"])).map(\.id)
    #expect(ids == ["validations", "badges", "reporting", "annonces-hall", "annuaire", "courriels"])
}

@Test func chaqueOngletADesDescriptifsDuSite() {
    #expect(TablesEspaceCS.descriptifs["validations"]?.isEmpty == false)
    #expect(TablesEspaceCS.civilites.first == AnnuaireCS.civiliteParDefaut)
}

// MARK: - Les services : réalisés par les deux, sans `nil` silencieux

@Test func lesDeuxServicesRealisentLesOngletsDuConseil() {
    let _: any ServiceComptesCS = ServiceAPI()
    let _: any ServiceComptesCS = ServiceSimule(delai: .zero)
    let _: any ServiceBadgesCS = ServiceAPI()
    let _: any ServiceBadgesCS = ServiceSimule(delai: .zero)
    let _: any ServiceAnnuaireCS = ServiceAPI()
    let _: any ServiceAnnuaireCS = ServiceSimule(delai: .zero)
    let _: any ServiceReportingCS = ServiceAPI()
    let _: any ServiceReportingCS = ServiceSimule(delai: .zero)
    let _: any ServiceAnnoncesHallCS = ServiceAPI()
    let _: any ServiceAnnoncesHallCS = ServiceSimule(delai: .zero)
    let _: any ServiceCourrielsCS = ServiceAPI()
    let _: any ServiceCourrielsCS = ServiceSimule(delai: .zero)
}

// MARK: - Relectures des réponses non typées

@Test func uneCommandeEnAttenteSeRelit() throws {
    let json = Data(
        """
        [{"id": 7, "user_id": 3, "lot_id": 12, "type": "vigik", "quantite": 2, "motif": null,
          "statut": "en_attente", "traite_par_id": null, "motif_refus": null,
          "cree_le": "2026-11-02T09:30:00", "traite_le": null,
          "demandeur_nom": "Sacha Exemple", "lot": "Lot 12", "batiment": "Bât. A"}]
        """.utf8)
    let commandes = try Relecture.lire([CommandeEnAttente].self, json: json)
    #expect(commandes.first?.demandeurNom == "Sacha Exemple")
    #expect(commandes.first?.quantite == 2)
    #expect(FormatsDuSite.dateCourte(commandes.first?.creeLe) == "02/11/2026")
}

@Test func leConseilEtLeSyndicSeRelisent() throws {
    let conseil = try Relecture.lire(
        ConseilCS.self,
        json: Data(
            """
            {"ag_annee": 2026, "ag_date": "2026-06-12", "whatsapp_url": "",
             "membres": [{"id": 1, "genre": "Mme", "prenom": "Alix", "nom": "Exemple", "batiment_id": 1,
               "batiment_nom": "A", "etage": 2, "est_gestionnaire_site": true, "est_president": true,
               "photo_url": null, "ordre": 0, "user_id": 4}]}
            """.utf8))
    #expect(conseil.membres.first?.estPresident == true)
    #expect(conseil.membres.first?.userId == 4)
    let syndic = try Relecture.lire(
        SyndicCS.self,
        json: Data(
            """
            {"nom_syndic": "Cabinet", "nom_syndic_source": "contrat", "adresse": "", "site_web": null,
             "membres": [{"id": 2, "genre": "Mr", "prenom": "Eudes", "nom": "Fictif", "fonction": null,
               "email": null, "telephone": "01 99 00 00 01, 06 99 00 00 02", "est_principal": false,
               "photo_url": null, "ordre": 0, "user_id": null}]}
            """.utf8))
    #expect(syndic.nomDuContrat)
    #expect(AnnuaireCS.telephones(syndic.membres.first?.telephone) == ["01 99 00 00 01", "06 99 00 00 02"])
}

// MARK: - Comptes & accès

@MainActor
@Test func approuverEtRejeterRetirentDeLaFile() async throws {
    let service = ServiceSimule(delai: .zero)
    let etat = EtatComptesCS()
    await etat.charger(service, ServiceSimule.residence)
    let premier = try #require(etat.comptes.first)
    let annonce = try await etat.valider(premier, accueil: AccueilArrivant(), service, ServiceSimule.residence)
    #expect(annonce.contains(TextesComptesCS.accueilEnvoye), "la case « Nouvel Arrivant » lance l'accueil")
    #expect(!etat.comptes.contains(premier))
    let commande = try #require(etat.commandes.first)
    #expect(try await etat.traiter(commande, accepter: nil, service, ServiceSimule.residence) == "Commande rejetée")
    #expect(!etat.commandes.contains(commande))
    // Relu : le serveur (simulé) ne les sert plus.
    await etat.charger(service, ServiceSimule.residence)
    #expect(!etat.comptes.contains(premier))
}

@MainActor
@Test func unCompteDejaTraiteRendLaPhraseDuServeur() async throws {
    let service = ServiceSimule(delai: .zero)
    let etat = EtatComptesCS()
    await etat.charger(service, ServiceSimule.residence)
    let compte = try #require(etat.comptes.first)
    try await service.traiterCompte(compte.id, valider: true, dans: ServiceSimule.residence)
    await #expect(throws: ErreurService.refus(.init(phrase: "Compte déjà traité"))) {
        _ = try await etat.rejeter(compte, service, ServiceSimule.residence)
    }
}

@Test func lesCodesSeDecoupentCommeSurLeSite() {
    #expect(EtatComptesCS.codes("4521, 417D5927;  9 ") == ["4521", "417D5927", "9"])
    #expect(EtatComptesCS.codes("  ").isEmpty, "laisser vide accepte sans rien créer")
}

// MARK: - Badges & télécommandes

@Test func laRechercheCherchePartoutSansAccents() {
    #expect(Recherche.contientTousLesMots(["4521", "Céleste Inventé", "Lot 12"], "celeste 12"))
    #expect(!Recherche.contientTousLesMots(["4521", "Alix Exemple", nil], "celeste"))
    #expect(Recherche.contientTousLesMots(["x"], "  "))
}

@Test func leParcSimuleMeleBadgesEtTelecommandes() async throws {
    let parc = try await ServiceSimule(delai: .zero).parc(ServiceSimule.residence)
    #expect(Set(parc.map(\.type)) == Set(TypeAcces.allCases))
    #expect(Set(parc.map(\.id)).count == parc.count, "un identifiant par type et par numéro")
}

// MARK: - Annuaire CS & Syndic

@Test func unSeulPresidentUnSeulPrincipal() {
    let conseil = ConseilCS(membres: [MembreConseil(estPresident: true), MembreConseil(), MembreConseil()])
    #expect(conseil.avecPresident(2).membres.map(\.estPresident) == [false, false, true])
    #expect(conseil.avecPresident(nil).membres.allSatisfy { $0.estPresident == false })
    let syndic = SyndicCS(membres: [MembreSyndic(nom: "A"), MembreSyndic(nom: "B", estPrincipal: true)])
    #expect(syndic.avecPrincipal(0).membres.map(\.estPrincipal) == [true, false])
    #expect(syndic.deplace(1, de: -1).membres.map(\.nom) == ["B", "A"])
    #expect(syndic.deplace(1, de: 1) == syndic, "le dernier ne descend pas")
}

@Test func lesTelephonesFontLAllerRetour() {
    #expect(AnnuaireCS.telephones(nil) == [""], "au moins un champ")
    #expect(AnnuaireCS.champTelephone([" 01 99 00 00 01 ", "", "06 99 00 00 02"]) == "01 99 00 00 01,06 99 00 00 02")
    #expect(AnnuaireCS.champTelephone(["  "]) == nil)
}

@Test func leJourDeLAGPartALaFormeDuServeur() throws {
    let date = try #require(FormatsDuSite.lire("2026-06-12"))
    #expect(AnnuaireCS.jour(date) == "2026-06-12")
}

@MainActor
@Test func enregistrerUneFicheNeuveLaNumerote() async throws {
    let service = ServiceSimule(delai: .zero)
    let etat = EtatAnnuaireCS()
    await etat.charger(service, ServiceSimule.residence)
    var conseil = try #require(etat.conseil.valeur)
    conseil.membres.append(MembreConseil(genre: "Mme", prenom: "Nouvelle", nom: "Fiche"))
    try await etat.enregistrer(conseil, service, ServiceSimule.residence)
    let relu = try #require(etat.conseil.valeur)
    #expect(relu.membres.count == conseil.membres.count)
    #expect(relu.membres.last?.id != nil, "le serveur numérote")

    var syndic = try #require(etat.syndic.valeur)
    syndic.nomSyndic = "Saisi à la main"
    try await etat.enregistrer(syndic, service, ServiceSimule.residence)
    #expect(etat.syndic.valeur?.nomSyndic == "Cabinet Exemple Gestion", "le contrat fait foi")
}
