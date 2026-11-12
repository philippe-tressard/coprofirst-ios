// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
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

// MARK: - Réponses typées depuis le contrat 1.12.0 (#55)

@Test func uneCommandeEnAttenteSeLitParSonType() async throws {
    let commandes = try await client(servant: FixturesComptesCS.commandes).getAdminCommandesAcces().ok.body.json
        .map(CommandeEnAttente.init)
    #expect(commandes.first?.demandeurNom == "Sacha Exemple" && commandes.first?.quantite == 2)
    #expect(FormatsDuSite.dateCourte(commandes.first?.creeLe) == "03/11/2026")
    #expect(try await ServiceSimule(delai: .zero).commandesEnAttente(ServiceSimule.residence) == commandes)
}

@Test func leConseilEtLeSyndicSeLisentParLeurType() async throws {
    let conseil = ConseilCS(try await client(servant: FixturesAnnuaireCS.conseil).getAdminAnnuaireCs().ok.body.json)
    #expect(conseil.membres.first?.estPresident == true && conseil.membres.first?.userId == 7)
    #expect(conseil.membres.first?.etageLibelle == "2ᵉ étage", "l'étage tel que le serveur le dit")
    #expect(conseil.membres[1].etageLibelle == nil, "un libellé vide se tait")
    let syndic = SyndicCS(try await client(servant: FixturesAnnuaireCS.syndic).getAdminAnnuaireSyndic().ok.body.json)
    #expect(syndic.nomDuContrat)
    #expect(syndic.membres.first?.telephones == ["01 99 00 12 34", "06 99 00 12 34"], "servis un par un")
    #expect(AnnuaireCS.champsTelephone(syndic.membres.first?.telephones ?? []) == ["01 99 00 12 34", "06 99 00 12 34"])
}

/// Le serveur refuse un interlocuteur sans téléphone en 422 avec SA phrase — pas la liste
/// d'une erreur de validation : le client généré ne la décode pas, l'app la lit quand même.
@Test func unRefusEn422DitLaPhraseDuServeur() async throws {
    let refus = #"{"detail": "L'interlocuteur Eudes Fictif n'a pas de téléphone."}"#
    let corps = Components.Schemas.SyndicIn(membres: [])
    await #expect(throws: ErreurService.refus(.init(phrase: "L'interlocuteur Eudes Fictif n'a pas de téléphone."))) {
        _ = try await ServiceAPI().appeler {
            try await client(servant: refus, statut: .unprocessableContent).putAdminAnnuaireSyndic(body: .json(corps))
        }
    }
}

// MARK: - Comptes & accès

@MainActor
@Test func approuverEtRejeterRetirentDeLaFile() async throws {
    let service = ServiceSimule(delai: .zero)
    let etat = EtatComptesCS()
    await etat.charger(service, ServiceSimule.residence)
    let premier = try #require(etat.comptes.first)
    let annonce = try await etat.valider(premier, accueil: AccueilArrivant(), service, ServiceSimule.residence)
    #expect(annonce?.texte.hasPrefix("Compte activé — 1 lot rattaché.") == true, "la phrase du serveur")
    #expect(annonce?.texte.contains(TextesComptesCS.accueilEnvoye) == true, "« Nouvel Arrivant » lance l'accueil")
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
    _ = try await service.traiterCompte(compte.id, valider: true, dans: ServiceSimule.residence)
    await #expect(throws: ErreurService.refus(.init(phrase: "Compte déjà traité"))) {
        _ = try await etat.rejeter(compte, service, ServiceSimule.residence)
    }
}

/// L'avertissement du serveur reste un avertissement : l'app ne compose plus « Compte
/// activé. », elle montre l'`annonce` avec son ton (#55).
@MainActor
@Test func laValidationMontreLAnnonceDuServeurAvecSonTon() async throws {
    let service = ServiceSimule(delai: .zero)
    let etat = EtatComptesCS()
    await etat.charger(service, ServiceSimule.residence)
    let sansLot = try #require(etat.comptes.first { $0.id == 502 })
    let annonce = try await etat.valider(sansLot, accueil: nil, service, ServiceSimule.residence)
    #expect(annonce == PhraseAvis(texte: "Compte activé. ⚠️ Aucun lot trouvé dans l'import.", ton: .warning))
    let avis = AvisDuGeste()
    if let annonce { avis.dire(annonce) }
    #expect(avis.ton == .warning && avis.texte?.contains("Aucun lot") == true)
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

/// « Par porteur » lit le rang SERVI (nom puis prénom), jamais `porteur_nom` qui commence
/// par le prénom ; les accès sans porteur viennent en dernier (#55).
@Test func leParcSeRangeParLeRangDuPorteur() async throws {
    let parc = try await ServiceSimule(delai: .zero).parc(ServiceSimule.residence).sorted(by: AccesDuParc.parPorteur)
    #expect(parc.map(\.porteurNom) == ["Basile Fictif", "Alix Exemple", "Alix Exemple", "Céleste Inventé", ""])
    #expect(parc.last?.porteurId == nil)
}

/// Ce qu'un accès ouvre se dit par le lieu SERVI (`perimetre_libelle`, #130) ; d'une
/// installation antérieure, par le LIBELLÉ de l'arbre servi, le périmètre par défaut tu
/// (`BadgePerimetre` du site) — jamais un code brut (« bat:2 », démo, 08/11/2026, #64).
@Test func ceQuUnAccesOuvreSeDitParSonLibelle() async throws {
    let service = ServiceSimule(delai: .zero)
    let arbre = try await service.perimetres(ServiceSimule.residence)
    let parc = try await service.parc(ServiceSimule.residence)
    let premier = try #require(parc.first { $0.id == "vigik-1" })
    #expect(premier.perimetreCible == ["copropriete", "bat_a"], "des codes, comme le serveur")
    #expect(premier.lieu(arbre: arbre) == "Bât. A", "le lieu servi, pas celui de l'arbre")
    #expect(LieuServi.libelles(premier.perimetreCible, parmi: arbre) == ["Bâtiment A"])
    #expect(LieuServi.libelles(["bat:2"], parmi: arbre).isEmpty, "un code inconnu ne s'affiche pas brut")
    #expect(LieuServi.libelles(["bat_b"], parmi: []).isEmpty, "sans arbre, rien plutôt qu'un code")
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
    #expect(AnnuaireCS.champsTelephone([]) == [""], "au moins un champ")
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
    #expect(etat.syndic.valeur?.nomSyndic == "Cabinet Exemple Gestion", "ce que le serveur a retenu : le contrat")
}

/// Le nom saisi se rapproche d'un inscrit et d'un logement — le SERVEUR le dit (#55).
@Test func unNomSaisiSeRapprocheParLeServeur() async throws {
    let service = ServiceSimule(delai: .zero)
    let trouve = try await service.rapprochement(nom: "Exemple", localiser: true, dans: ServiceSimule.residence)
    #expect(trouve == Rapprochement(userId: 7, batimentId: 1, batimentNom: "A", etage: 2, etageLibelle: "2ème étage"))
    let sansLogement = try await service.rapprochement(nom: "Exemple", localiser: false, dans: ServiceSimule.residence)
    #expect(sansLogement == Rapprochement(userId: 7), "un interlocuteur du syndic n'a pas de logement")
    #expect(try await service.rapprochement(nom: "Inconnu", localiser: true, dans: ServiceSimule.residence) == .init())
    let lu = try await client(servant: FixturesAnnuaireCS.rapprochementExemple)
        .getAdminAnnuaireRapprochement(query: .init(nom: "Exemple")).ok.body.json
    #expect(Rapprochement.lu(lu, corps: Data(FixturesAnnuaireCS.rapprochementExemple.utf8)) == trouve)
}
