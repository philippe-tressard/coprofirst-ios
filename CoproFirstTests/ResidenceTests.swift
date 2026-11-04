// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

// Ma résidence et l'Annuaire (#12).

// MARK: - Inscription et service du menu

@MainActor
@Test func laResidenceEtLAnnuaireSontInscrits() {
    #expect(RegistreDesMenus.ecrans["residence"] == ResidenceView.self)
    #expect(RegistreDesMenus.ecrans["annuaire"] == AnnuaireView.self)
}

/// Les deux réalisations du service portent le service du menu : une conformité qui
/// manquerait laisserait l'écran vide sans que rien ne le dise. Vérifiée à la
/// compilation (les affectations) et à l'exécution (le pont depuis `ServiceCoproFirst`).
@Test func lesDeuxServicesPortentLeServiceDuMenu() {
    let api: any ServiceResidence = ServiceAPI()
    let simule: any ServiceResidence = ServiceSimule(delai: .zero)
    let annuaires: [any ServiceAnnuaire] = [ServiceAPI(), ServiceSimule(delai: .zero)]
    #expect(api is ServiceAPI && simule is ServiceSimule && annuaires.count == 2)
    let services: [any ServiceCoproFirst] = [ServiceAPI(), ServiceSimule(delai: .zero)]
    for service in services {
        #expect(service.residence != nil)
        #expect(service.annuaire != nil)
    }
}

// MARK: - Onglets réservés (la table générée du site, #30)

private func droits(statut: String?, _ roles: String...) -> DroitsOnglet {
    DroitsOnglet(profil: ProfilResidence(statut: statut, roles: roles, libelleLogement: nil))
}

private func ids(_ onglets: [OngletDuSite]) -> [String] { onglets.map(\.id) }

@Test func unLocataireNeVoitQueLaFiche() {
    let locataire = droits(statut: "locataire", "résident")
    #expect(ids(OngletsResidence.ouverts(locataire, accesReglement: true)) == ["fiche"])
    #expect(locataire.locataire)
}

@Test func unProprietaireVoitLeCarnetEtLeReglement() {
    let proprietaire = droits(statut: "copropriétaire_résident", "résident", "propriétaire")
    #expect(ids(OngletsResidence.ouverts(proprietaire, accesReglement: true)) == ["fiche", "carnet", "reglement"])
    #expect(!proprietaire.cs)
}

/// Chaque onglet ouvert a son écran : un onglet que l'app ne sait pas rendre ne
/// s'affiche pas, plutôt que d'ouvrir la Fiche sous un autre nom.
@Test func chaqueOngletDuSiteASonEcran() {
    let cs = droits(statut: nil, "conseil_syndical")
    #expect(cs.cs && cs.proprioOuCS)
    for onglet in OngletsResidence.ouverts(cs, accesReglement: true) {
        #expect(OngletResidence(rawValue: onglet.id) != nil, "« \(onglet.id) » sans écran")
    }
    #expect(OngletsResidence.ouverts(DroitsOnglet(profil: nil), accesReglement: true).count == 1, "profil inconnu")
}

/// L'administration n'a pas ouvert l'assistant : l'onglet se masque. Tant qu'elle n'a
/// pas répondu (`nil`), il reste — un lien reçu avant ne serait pas renvoyé ailleurs.
@Test func leReglementSeMasqueQuandLAccesEstFerme() {
    let proprietaire = droits(statut: "copropriétaire_bailleur", "propriétaire")
    #expect(ids(OngletsResidence.ouverts(proprietaire, accesReglement: false)) == ["fiche", "carnet"])
    #expect(ids(OngletsResidence.ouverts(proprietaire, accesReglement: nil)).contains("reglement"))
}

// MARK: - Fiche

@Test func laFicheDitLeMandatEchuEtLaReconduction() throws {
    let jour = try #require(FormatsDuSite.lire("2026-06-30"))
    #expect(TextesResidence.mandat(jour, echu: true) == " — mandat échu depuis le 30/06/2026")
    #expect(TextesResidence.mandat(jour, echu: false) == " — mandat jusqu'au 30/06/2026")
    #expect(TextesResidence.echeance(jour, reconduit: true) == " — échéance 30/06/2026 (reconduit tacitement)")
    #expect(TextesResidence.echeance(nil, reconduit: true).isEmpty)
}

/// La gouttière : la date de `fmtDate` en trois morceaux, comme `partiesDate` du site.
@Test func laGouttiereDecoupeLaDateDuSite() throws {
    let jour = try #require(FormatsDuSite.lire("2026-04-02"))
    #expect(Gouttiere.parties(jour) == ["2", "avr.", "2026"])
}

@Test func lesAnnexesSeRangentSousLeurFiche() {
    let contenu = ServiceSimule.contenuFiche
    #expect(contenu.annexes(deRegle: 1).map(\.id) == [40])
    #expect(contenu.annexes(deDocument: 11).map(\.id) == [41])
    #expect(contenu.annexes(deRapport: 5).isEmpty)
    #expect(contenu.libelleBatiment(1) == "Bât. A")
    #expect(contenu.libelleBatiment(nil) == "Copropriété")
    #expect(contenu.libelleBatiment(99) == "Bât. ?")
}

// MARK: - Carnet

@Test func leCarnetSeRangeParEquipementDansLOrdreDuServeur() {
    let carnet = ContenuCarnet(entrees: ServiceSimule.carnet, libellesEquipements: ["chaufferie": "Chaufferie"])
    #expect(carnet.groupes.map(\.titre) == ["Chaufferie", "ascenseur", "toiture", TextesCarnet.sansEquipement])
    #expect(carnet.groupes.first?.entrees.count == 2)
    #expect(carnet.enAlerte.map(\.libelle) == ["Contrat d'entretien de l'ascenseur"])
    #expect(TextesCarnet.visitesAttendues(1) == "1 visite attendue")
    #expect(TextesCarnet.visitesAttendues(3) == "3 visites attendues")
}

/// La réponse du carnet n'est pas typée dans le contrat : elle se relit telle que le
/// serveur la sert — un champ inconnu ne la casse pas, un champ absent reste vide.
@Test func leCarnetSeLitDepuisLeJSONDuServeur() throws {
    let json = """
        {"total": 1, "entrees": [{"date": "2026-05-02", "libelle": "Ramonage", "origine": "intervention",
        "detail": "", "perimetre": ["bat_a"], "lien": "/prestataires", "inconnu": 3}]}
        """
    let carnet = try JSONDecoder().decode(Carnet.self, from: Data(json.utf8))
    #expect(carnet.entrees.first?.libelle == "Ramonage")
    #expect(carnet.entrees.first?.equipement == nil)
    #expect(carnet.entrees.first?.jour != nil)
}

// MARK: - Règlement

@Test func lesExtraitsSeLisentAvecCeQueLeCodeAVerifie() {
    let question = ServiceSimule.question
    #expect(question.verifies == 1)
    #expect(question.extraitsReglement.count == 2 && question.extraitsAG.isEmpty)
    #expect(question.extraits.first?.origine == "Règlement de copropriété — 14")
    #expect(question.extraits.last?.origine == "Art. 4", "sans acte ni page : la référence donnée")
}

@Test func uneQuestionPoseeRevientEnTete() async throws {
    let service = ServiceSimule(delai: .zero)
    let posee = try await service.poser("Puis-je fermer mon balcon ?", dans: ServiceSimule.residence)
    let (_, questions) = try await service.reglement(ServiceSimule.residence)
    #expect(questions.first?.id == posee.id)
    #expect(questions.first?.question == "Puis-je fermer mon balcon ?")
}

// MARK: - Annuaire

@Test func lAnnuaireSeLitDepuisLeJSONDuServeur() throws {
    let json = """
        {"cs": {"ag_annee": 2025, "ag_date": "2025-06-20", "membres": [
          {"id": 1, "genre": "Mme", "prenom": "Alix", "nom": "Exemple", "batiment_nom": "A",
           "est_gestionnaire_site": false, "est_president": true, "etage": 2}]},
         "syndic": {"nom_syndic": "Cabinet", "nom_syndic_source": "contrat", "adresse": "",
          "membres": [{"id": 9, "prenom": "Elsa", "nom": "Gestion", "telephone": "01 02, 01 02 , 06 07",
           "est_principal": true}]},
         "whatsapp_url": null}
        """
    let decodeur = JSONDecoder()
    decodeur.keyDecodingStrategy = .convertFromSnakeCase
    let annuaire = try decodeur.decode(Annuaire.self, from: Data(json.utf8))
    #expect(annuaire.cs.membres.first?.estPresident == true)
    #expect(annuaire.cs.membres.first?.nomComplet == "Mme Alix Exemple")
    #expect(annuaire.syndic.membres.first?.telephones == ["01 02", "06 07"], "un doublon ne s'affiche qu'une fois")
    #expect(annuaire.syndic.membres.first?.initiales == "EG")
}

@Test func leConseilSeGroupeParBatimentSansBatimentEnDernier() {
    let groupes = ServiceSimule.annuaire.groupesCS
    #expect(groupes.map(\.batiment) == ["A", "B", nil])
    #expect(groupes.first?.membres.count == 2)
}
