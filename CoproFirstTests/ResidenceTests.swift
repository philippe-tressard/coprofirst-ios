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

// MARK: - Onglets réservés (mêmes droits que le site)

private func profil(statut: String?, _ roles: String...) -> ProfilResidence {
    ProfilResidence(statut: statut, roles: roles, libelleLogement: nil)
}

@Test func unLocataireNeVoitQueLaFiche() {
    let locataire = profil(statut: "locataire", "résident")
    #expect(OngletResidence.ouverts(locataire, accesReglement: true) == [.fiche])
    #expect(DroitsResidence.locataire(locataire))
}

@Test func unProprietaireVoitLeCarnetEtLeReglement() {
    let proprietaire = profil(statut: "copropriétaire_résident", "résident", "propriétaire")
    #expect(OngletResidence.ouverts(proprietaire, accesReglement: true) == [.fiche, .carnet, .reglement])
    #expect(!DroitsResidence.cs(proprietaire))
}

@Test func leConseilEtLAdministrateurSontProprioOuCS() {
    #expect(DroitsResidence.proprioOuCS(profil(statut: "locataire", "conseil_syndical")))
    #expect(DroitsResidence.proprioOuCS(profil(statut: nil, "admin")))
    #expect(DroitsResidence.cs(profil(statut: nil, "admin")))
    #expect(!DroitsResidence.proprioOuCS(nil), "profil inconnu : rien de réservé ne s'ouvre")
}

/// L'administration n'a pas ouvert l'assistant : l'onglet se masque. Tant qu'elle n'a
/// pas répondu (`nil`), il reste — un lien reçu avant ne serait pas renvoyé ailleurs.
@Test func leReglementSeMasqueQuandLAccesEstFerme() {
    let proprietaire = profil(statut: "copropriétaire_bailleur", "propriétaire")
    #expect(OngletResidence.ouverts(proprietaire, accesReglement: false) == [.fiche, .carnet])
    #expect(OngletResidence.ouverts(proprietaire, accesReglement: nil).contains(.reglement))
}

// MARK: - Fiche

@Test func laFicheDitLeMandatEchuEtLaReconduction() throws {
    let jour = try #require(Dates.jour("2026-06-30"))
    #expect(TextesResidence.mandat(jour, echu: true) == " — mandat échu depuis le 30/06/2026")
    #expect(TextesResidence.mandat(jour, echu: false) == " — mandat jusqu'au 30/06/2026")
    #expect(TextesResidence.echeance(jour, reconduit: true) == " — échéance 30/06/2026 (reconduit tacitement)")
    #expect(TextesResidence.echeance(nil, reconduit: true).isEmpty)
}

@Test func unJourServiResteLeMemeJour() throws {
    let jour = try #require(Dates.jour("2026-03-01T00:00:00"))
    #expect(Calendar.current.component(.day, from: jour) == 1)
    #expect(Dates.jour("pas une date") == nil)
    #expect(Dates.jour(nil) == nil)
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
