// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// « Mes lots & accès » et « Prestataires » (#13) : services, droits, formats, règles.

/// Les deux services de l'app réalisent les services des deux menus — sinon l'écran
/// tomberait sur « Bientôt » (`Parcours.serviceAcces`).
@Test func lesDeuxServicesRealisentLesMenus() {
    let services: [any ServiceCoproFirst] = [ServiceAPI(), ServiceSimule(delai: .zero)]
    for service in services {
        #expect(service is any ServiceAcces)
        #expect(service is any ServicePrestataires)
    }
}

@MainActor
@Test func lesDeuxMenusSontInscrits() {
    #expect(RegistreDesMenus.ecrans["mon-lot"] == AccesView.self)
    #expect(RegistreDesMenus.ecrans["prestataires"] == PrestatairesView.self)
}

// MARK: - Droits : ce qui s'affiche selon ce que l'on est

@Test func leLocataireNeGerePasDeBaux() {
    let droits = DroitsAcces(ProfilResidence(statut: "locataire", roles: ["résident"]))
    #expect(droits.locataire)
    #expect(droits.baux == nil)
    #expect(!droits.voitLocation(bauxTermines: 3))
}

@Test func leBailleurLitSesBauxEtVoitLaGestionLocative() {
    let droits = DroitsAcces(ProfilResidence(statut: "copropriétaire_bailleur", roles: ["propriétaire"]))
    #expect(droits.baux == .siens)
    #expect(droits.voitLocation(bauxTermines: 0))
}

@Test func leResidentNeVoitLaGestionLocativeQuAvecDesBauxTermines() {
    let droits = DroitsAcces(ProfilResidence(statut: "copropriétaire_résident", roles: ["propriétaire"]))
    #expect(!droits.voitLocation(bauxTermines: 0))
    #expect(droits.voitLocation(bauxTermines: 1))
}

@Test func leConseilLitTousLesBauxSAilNEstPasCoproprietaire() {
    let conseil = DroitsAcces(ProfilResidence(statut: nil, roles: ["conseil_syndical"]))
    #expect(conseil.baux == .tous)
    // Copropriétaire ET conseil : ses baux d'abord, comme `lireBaux` du site.
    let lesDeux = DroitsAcces(ProfilResidence(statut: "copropriétaire_bailleur", roles: ["conseil_syndical"]))
    #expect(lesDeux.baux == .siens)
}

/// « Nouvel accès » n'est offert qu'à qui a un lot : la route exige qu'il soit le sien.
@Test func nouvelAccesExigeUnLot() throws {
    let droits = DroitsAcces(nil)
    #expect(!droits.peutDemander(lots: []))
    #expect(droits.peutDemander(lots: try FixturesAcces.lots()))
}

@Test func uneDemandeHorsDeSesLotsEstRefusee() async {
    let service = ServiceSimule(delai: .zero)
    let voisin = DemandeAcces(type: .vigik, lotId: 999)
    await #expect(throws: ErreurService.refus(.init(phrase: "Vous n'êtes pas associé à ce lot"))) {
        try await service.demander(voisin, dans: ServiceSimule.residence)
    }
}

// MARK: - Formats du site

@Test func lesDatesSuiventLeSite() {
    #expect(FormatsDuSite.dateCourte("2026-04-10") == "10/04/2026")
    #expect(FormatsDuSite.date("2026-04-02") == "2 avr. 2026")
    #expect(FormatsDuSite.dateCourte(nil as String?) == "—")
}

@Test func lesNombresSuiventLeSite() {
    // `Intl.NumberFormat('fr-FR')` : espace fine insécable, virgule décimale.
    #expect(FormatsDuSite.nombre(47_047) == "47\u{202F}047")
    #expect(FormatsDuSite.nombre(64.5) == "64,5")
    #expect(FormatsDuSite.nombre(nil as Int?) == "—")
}

// MARK: - Tables générées, et rien de recopié

@Test func lesLibellesViennentDesTablesGenerees() {
    #expect(LibellesAcces.statutAcces("perdu") == LibelleTeinte("Perdu", "badge-red"))
    #expect(LibellesAcces.statutBail("en_cours_sortie").libelle == "En cours de sortie")
    #expect(LibellesAcces.typeAcces("telecommande") == "📡 Télécommande parking")
    #expect(LibellesPrestataires.type("reglementaire") == "📋 Réglementaire")
    // Une valeur inconnue s'affiche brute : un libellé manquant doit se voir.
    #expect(LibellesAcces.statutAcces("inconnu") == LibelleTeinte("inconnu", "badge-gray"))
    #expect(LibellesAcces.typeAcces("badge_rfid") == "badge_rfid")
}

/// `lotTypeLabel`, `etageLabel`, `nomAffiche` ne sont pas recopiés : le libellé que
/// l'API sert (contrat 1.5.0), sinon la donnée brute.
@Test func leLotEtLesNomsSAffichentCommeLApiLesSert() throws {
    let lots = try FixturesAcces.lots()
    #expect(lots[0].typeLu == "Appartement – T3")
    #expect(lots[0].etageLu == "2ème")
    var sansLibelle = lots[1]
    sansLibelle.libelleTypeComplet = nil
    sansLibelle.etageLibelle = ""
    #expect(sansLibelle.typeLu == "cave")
    #expect(sansLibelle.etageLu == "-1")
    // Le repli d'une installation qui ne sert pas encore le nom affiché (#135).
    #expect(FormatsDuSite.nom(affiche: nil, prenom: " Marie ", nom: "Durand") == "Marie Durand")
    #expect(FormatsDuSite.nom(affiche: nil, prenom: nil, nom: "  ") == "—")
}

@Test func lesBauxSeGroupentParLocataire() throws {
    let groupes = GroupesDeBaux.parLocataire(try FixturesAcces.bauxLus())
    // Le bail 4 n'a pas de locataire inscrit : il fait groupe seul.
    #expect(groupes.map(\.cle) == ["81", "ext_4", "80"])
}

@Test func laVueParLocataireRattacheLesObjetsConfies() throws {
    let bail = try FixturesAcces.bauxLus()[0]
    let confie = AccesDetenu(id: 1, code: "X", statut: "actif", type: "vigik", chezLocataire: true, bailId: bail.id)
    let garde = AccesDetenu(id: 2, code: "Y", statut: "actif", type: "vigik", chezLocataire: false, bailId: bail.id)
    let groupes = GroupeAcces.grouper([bail], objets: [confie, garde])
    #expect(groupes.count == 1)
    #expect(groupes[0].objets == [confie])
}

@Test func laRechercheIgnoreAccentsCasseEtOrdre() throws {
    let fiche = try FixturesPrestataires.lus()[1]
    #expect(LibellesPrestataires.correspond(fiche, equipement: "Sécurité incendie", recherche: "INCENDIE controles"))
    #expect(!LibellesPrestataires.correspond(fiche, equipement: "Sécurité incendie", recherche: "ascenseur"))
}

@Test func lesContratsSeRangentParEcheance() {
    let ranges = PrestatairesSimules.contrats.sorted(by: LibellesPrestataires.parEcheance).map(\.id)
    #expect(ranges == [2, 1, 3], "la visite la plus proche d'abord, sans échéance à la fin")
}

// MARK: - Les onglets viennent de `OngletsDuSite` (#30)

/// Les descriptifs générés ici et les onglets générés pour toute l'app lisent le même
/// `pages.ts` : chaque onglet a son descriptif, et aucun descriptif n'est orphelin.
@Test func chaqueOngletASonDescriptif() {
    let tables = [("mon-lot", TablesAcces.descriptifs), ("prestataires", TablesPrestataires.descriptifs)]
    for (page, descriptifs) in tables {
        let ids = Set((OngletsDuSite.parPage[page] ?? []).map(\.id))
        #expect(!ids.isEmpty, "\(page) : aucun onglet généré")
        #expect(Set(descriptifs.keys) == ids, "\(page) : descriptifs et onglets divergent")
    }
}

/// « Gestion locative » : ouverte par le site à tous, masquée par l'écran à qui ne
/// gère pas de bail (masquage qui dépend des données).
@MainActor
@Test func laGestionLocativeSeMasqueSansBail() {
    let etat = EtatAcces()
    etat.droits = DroitsAcces(ProfilResidence(statut: "locataire", roles: ["résident"]))
    #expect(etat.onglets.map(\.id) == ["lots", "badges", "telecommandes"])
    etat.droits = DroitsAcces(ProfilResidence(statut: "copropriétaire_bailleur", roles: ["propriétaire"]))
    #expect(etat.onglets.map(\.id) == ["lots", "badges", "telecommandes", "location"])
}
