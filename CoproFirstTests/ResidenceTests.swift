// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
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
    let contenu = Apercu.contenuFiche
    #expect(contenu.annexes(deRegle: 1).map(\.id) == [40])
    #expect(contenu.annexes(deDocument: 11).map(\.id) == [41])
    #expect(contenu.annexes(deRapport: 5).isEmpty)
    #expect(contenu.libelleBatiment(1) == "Bât. A")
    #expect(contenu.libelleBatiment(nil) == "Copropriété")
    #expect(contenu.libelleBatiment(99) == "Bât. ?")
}

// MARK: - Carnet

@Test func leCarnetSeRangeParEquipementDansLOrdreDuServeur() {
    let carnet = ContenuCarnet(entrees: Apercu.carnet, libellesEquipements: ["chaufferie": "Chaufferie"])
    #expect(carnet.groupes.map(\.titre) == ["Chaufferie", "ascenseur", "toiture", TextesCarnet.sansEquipement])
    #expect(carnet.groupes.first?.entrees.count == 2)
    #expect(carnet.enAlerte.map(\.libelle) == ["Contrat d'entretien de l'ascenseur"])
    #expect(TextesCarnet.visitesAttendues(1) == "1 visite attendue")
    #expect(TextesCarnet.visitesAttendues(3) == "3 visites attendues")
}

/// Le carnet est typé par le contrat 1.5.0 (`CarnetLu`) : décodé comme le client,
/// branché par `EntreeCarnet(_:)` — un champ inconnu ne le casse pas, un champ absent
/// reste vide.
@Test func leCarnetSeLitDepuisLeJSONDuServeur() throws {
    let json = """
        {"total": 1, "annees": ["2026"], "groupes": [], "entrees": [{"date": "2026-05-02", "libelle": "Ramonage",
        "origine": "intervention", "categorie_libelle": "Entretien", "perimetre_libelle": "Bâtiment A",
        "detail": "", "perimetre": ["bat_a"], "lien": "/prestataires", "inconnu": 3}]}
        """
    let entrees = try Relecture.generee(Components.Schemas.CarnetLu.self, json: json).entrees.map(EntreeCarnet.init)
    #expect(entrees.first?.libelle == "Ramonage")
    #expect(entrees.first?.equipement == nil)
    #expect(entrees.first?.jour != nil)
}

// MARK: - Règlement

@Test func lesExtraitsSeLisentAvecCeQueLeCodeAVerifie() {
    let question = Apercu.question
    #expect(question.verifies == 2)
    #expect(question.extraitsReglement.count == 2 && question.extraitsAG.count == 1)
    // L'acte, la rubrique et la page, joints par le séparateur du site : insécable après le tiret.
    #expect(question.extraits.first?.origine == "Règlement de copropriété —\u{00A0}Chapitre II —\u{00A0}p. 14")
    #expect(question.extraits[1].origine == "Art. 4", "sans acte ni page : la référence donnée")
}

/// Un avis à renvois se lit par ses fondements — le règlement, puis les AG —, un avis
/// d'avant section après section ; le ton du verdict est servi, sa teinte générée.
@Test func unAvisARenvoisSeLitParSesFondements() {
    let question = Apercu.question
    #expect(question.avecRenvois)
    #expect(question.fondements.compactMap(\.renvoi) == ["R1", "R2", "AG1"])
    #expect(!Apercu.questionAvant.avecRenvois)
    #expect(question.badgeDuVerdict == "badge-orange")
    #expect(Apercu.questionAvant.badgeDuVerdict == "badge-red")
    var inconnu = question
    inconnu.verdictTon = "incertain"
    #expect(inconnu.badgeDuVerdict == TablesReglement.badgeDuVerdictInconnu, "un ton inconnu se lit incertain")
    #expect(TextesAvis.sansExtrait(["R3"]) == "Renvoi sans extrait —\u{00A0}à vérifier\u{00A0}: R3.")
    #expect(TextesAvis.sansExtrait(["R3", "AG2"]).hasPrefix("Renvoi sans extraits"))
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
          {"id": 1, "genre": "Mme", "prenom": "Alix", "nom": "Exemple", "nom_affiche": "Alix EXEMPLE",
           "batiment_nom": "A", "est_gestionnaire_site": false, "est_president": true, "etage": 2,
           "etage_libelle": "2ᵉ étage"}]},
         "syndic": {"nom_syndic": "Cabinet", "nom_syndic_source": "contrat", "adresse": "",
          "membres": [{"id": 9, "genre": "", "prenom": "Elsa", "nom": "Gestion", "nom_affiche": "Elsa GESTION",
           "telephone": "01 02, 01 02 , 06 07", "telephones": ["01 02", "06 07"], "est_principal": true}]},
         "whatsapp_url": null}
        """
    // Typé par le contrat 1.5.0 (`AnnuaireLu`) : décodé comme le client, branché par `Annuaire(_:)`.
    let annuaire = Annuaire(try Relecture.generee(Components.Schemas.AnnuaireLu.self, json: json))
    #expect(annuaire.cs.membres.first?.estPresident == true)
    #expect(annuaire.cs.membres.first?.nomComplet == "Mme Alix Exemple")
    #expect(annuaire.syndic.membres.first?.telephones == ["01 02", "06 07"], "un doublon ne s'affiche qu'une fois")
    #expect(annuaire.syndic.membres.first?.initiales == "EG")
}

@Test func leConseilSeGroupeParBatimentSansBatimentEnDernier() {
    let groupes = Apercu.annuaire.groupesCS
    #expect(groupes.map(\.batiment) == ["A", "B", nil])
    #expect(groupes.first?.membres.count == 2)
}

/// Contrat 1.14.0 : l'aperçu de la carte lit la réponse SANS ses renvois, et l'avis dit
/// les renvois sans extrait — servis par l'API, jamais recalculés par l'app (#60).
@Test func uneQuestionAuReglementLitSesRenvoisServis() throws {
    let json = """
        {"id": 7, "texte_id": 1, "question": "Q ?", "reponse": "<p>Oui [R1], sauf [R2].</p>",
        "reponse_sans_renvois": "<p>Oui, sauf.</p>", "renvois_sans_extrait": ["R2"], "verdict": "oui",
        "verdict_libelle": "Oui", "verdict_ton": "succes", "texte_en_vigueur": true,
        "cree_le": "2026-11-10T08:00:00", "extraits": [{"citation": "C", "verifie": true, "renvoi": "R1"}]}
        """
    let lue = try Relecture.generee(Components.Schemas.QuestionReglementRead.self, json: json)
    let question = QuestionReglement(lue: lue)
    #expect(question.reponseSansRenvois == "<p>Oui, sauf.</p>")
    #expect(question.renvoisSansExtrait == ["R2"])
    #expect(question.extraits.count == 1)
    #expect(question.verdictTon == "succes" && question.badgeDuVerdict == "badge-green")
    #expect(question.avecRenvois && question.extraits.first?.renvoi == "R1")
}

/// Le lieu d'un extrait vient du serveur — acte, rubrique, page —, jamais du modèle.
@Test func unExtraitLitSaRubriqueEtSonRenvoiServis() throws {
    let json = """
        {"id": 8, "texte_id": 1, "question": "Q ?", "reponse": "<p>Non [AG1].</p>",
        "reponse_sans_renvois": "<p>Non.</p>", "renvois_sans_extrait": [], "verdict": "non",
        "verdict_libelle": "Non", "verdict_ton": "danger", "texte_en_vigueur": true,
        "cree_le": "2026-11-10T08:00:00", "extraits": [{"citation": "C", "verifie": true, "renvoi": "AG1",
        "source": "ag", "acte": "AG du 3 mai 2025", "rubrique": "Résolution 4", "page": "p. 2"}]}
        """
    let lue = try Relecture.generee(Components.Schemas.QuestionReglementRead.self, json: json)
    let question = QuestionReglement(lue: lue)
    #expect(question.extraitsAG.first?.rubrique == "Résolution 4")
    #expect(question.fondements.first?.origine == "AG du 3 mai 2025 —\u{00A0}Résolution 4 —\u{00A0}p. 2")
}
