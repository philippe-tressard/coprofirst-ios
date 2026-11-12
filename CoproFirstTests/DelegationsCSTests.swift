// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

// Les Délégations aidant et trois onglets de l'Espace CS (#15) : Reporting, Annonces
// Hall, Courriels affaires.

// MARK: - Les deux services réalisent les protocoles

@Test func lesDeuxServicesRealisentLesDelegations() {
    let _: any ServiceDelegations = ServiceAPI()
    let _: any ServiceDelegations = ServiceSimule(delai: .zero)
}

/// La page Délégations s'ouvre au conseil et à l'aidant (`Nav.svelte`), pas au résident.
@Test func laPageDesDelegationsSOuvreALAidant() {
    let resident = ProfilResidence(statut: "copropriétaire_résident", roles: ["propriétaire"])
    #expect(!PagesOuvertes.ouverte("delegations", droits: DroitsOnglet(profil: resident)))
    var aide = resident
    aide.delegationsAidant = 1
    #expect(PagesOuvertes.ouverte("delegations", droits: DroitsOnglet(profil: aide)))
    let aidant = ProfilResidence(statut: "aidant", roles: [])
    #expect(PagesOuvertes.ouverte("delegations", droits: DroitsOnglet(profil: aidant)))
    let conseil = ProfilResidence(
        statut: "copropriétaire_résident", roles: ["propriétaire", "conseil_syndical"], estModerateur: true)
    #expect(PagesOuvertes.ouverte("delegations", droits: DroitsOnglet(profil: conseil)))
}

// MARK: - Délégations

/// `GET /delegations` est typé (`DelegationRead`, contrat 1.8.0) : la réponse traverse le
/// client GÉNÉRÉ — ses dates comprises — puis `Delegation(_:)` (#56).
@Test func uneDelegationSeLitParSonTypeGenere() async throws {
    let lues = try await client(servant: FixturesDelegations.delegations).getDelegations().ok.body.json
        .map(Delegation.init)
    let enAttente = try #require(lues.first)
    #expect(enAttente.mandantNom == "Lucie Exemple" && enAttente.aidantId == 7)
    #expect(TextesDelegations.periode(enAttente) == "Du 06/11/2026 au 04/02/2027")
    let active = try #require(lues.first { $0.statut == "active" })
    #expect(active.dateFin == nil && TextesDelegations.periode(active) == "Du 11/07/2026 — illimité")
    // La simulation lit les mêmes octets par le même branchement.
    #expect(try await ServiceSimule(delai: .zero).delegations(ServiceSimule.residence) == lues)
}

/// Les gestes sont SERVIS pour le compte qui lit (`peut_accepter`, `peut_revoquer`) :
/// l'app ne les déduit ni du statut ni de qui est l'aidant (#56).
@Test func lesGestesDUneDelegationSontCeuxQueLeServeurOuvre() async throws {
    let lues = try FixturesDelegations.delegationsLues()
    let enAttente = try #require(lues.first { $0.statut == "en_attente" })
    #expect(enAttente.peutAccepter && enAttente.peutRevoquer)
    let active = try #require(lues.first { $0.statut == "active" })
    #expect(!active.peutAccepter && active.peutRevoquer)
    let revoquee = try #require(lues.first { $0.statut == "revoquee" })
    #expect(!revoquee.peutAccepter && !revoquee.peutRevoquer)
    // Absents d'une réponse : aucun geste, jamais un geste deviné.
    let json = #"""
        [{"id": 1, "mandant_id": 1, "mandant_nom": "A", "aidant_id": 2, "aidant_nom": "B", "statut": "en_attente",
          "motif": "", "date_debut": "2026-04-02", "cree_le": "2026-04-02T08:00:00"}]
        """#
    let sansGestes = try #require(try await client(servant: json).getDelegations().ok.body.json.first)
    #expect(!Delegation(sansGestes).peutAccepter && !Delegation(sansGestes).peutRevoquer)
}

@Test func lEtatDUneDelegationEstCeluiDuSite() {
    #expect(TablesDelegations.statuts["active"] == LibelleTeinte("Active", "badge-green"))
    // `expiree` porte `badge-gray` — la classe de la charte, pas `badge-grey`.
    #expect(TablesDelegations.statuts["expiree"]?.badge == "badge-gray")
    var inconnue = Delegation(
        id: 1, mandantId: 1, mandantNom: "", aidantId: 2, aidantNom: "", statut: "suspendue", motif: "",
        dateDebut: nil, dateFin: nil)
    #expect(inconnue.libelleStatut == .brut("suspendue"), "une valeur inconnue s'affiche brute")
    inconnue.statut = "en_attente"
    #expect(inconnue.libelleStatut.libelle == "En attente")
}

@Test func uneDelegationLieDeuxPersonnesDistinctes() {
    var saisie = SaisieDelegation()
    #expect(!saisie.complete)
    saisie.mandant = 3
    #expect(!saisie.complete)
    saisie.aidant = 3
    #expect(!saisie.complete, "le mandant et l'aidant doivent être différents")
    saisie.aidant = 7
    #expect(saisie.complete)
}

@Test func lesGestesSimulesChangentLaListe() async throws {
    let service = ServiceSimule(delai: .zero)
    let residence = ServiceSimule.residence
    let avant = try await service.delegations(residence)
    let enAttente = try #require(avant.first { $0.peutAccepter })
    let acceptee = try await service.accepterDelegation(enAttente.id, dans: residence)
    #expect(acceptee.statut == "active" && !acceptee.peutAccepter, "la réponse porte les gestes d'après")
    await #expect(throws: ErreurService.self) { try await service.accepterDelegation(enAttente.id, dans: residence) }
    let revoquee = try await service.revoquerDelegation(enAttente.id, dans: residence)
    #expect(revoquee.statut == "revoquee" && !revoquee.peutRevoquer)
    var saisie = SaisieDelegation(mandant: 4, aidant: 7, motif: "Essai")
    saisie.dateFin = ISO8601DateFormatter().date(from: "2026-07-25T22:30:00Z")
    let creee = try await service.creerDelegation(saisie, dans: residence)
    #expect(creee.statut == "en_attente" && creee.dateFin == "2026-07-26", "le jour de Paris")
    #expect(try await service.delegations(residence).first?.id == creee.id)
    // Un autre service simulé garde sa propre liste.
    #expect(try await ServiceSimule(delai: .zero).delegations(residence).count == avant.count)
}

// MARK: - Formats du site ajoutés par #15

/// `jourIso` et `fmtDatetimeShort` (`front/src/lib/date.ts`, coprofirst v3.61.0) :
/// chaque attendu est leur sortie sous Node.
@Test(arguments: [
    ("2026-04-10T12:30:00Z", "10/04/2026 14:30", "2026-04-10"),
    ("2026-07-25T22:00:00Z", "26/07/2026 00:00", "2026-07-26"),
    ("2026-01-31T23:30:00Z", "01/02/2026 00:30", "2026-02-01"),
    ("2026-03-29T00:30:00Z", "29/03/2026 01:30", "2026-03-29"),
])
func leJourEtLaDateHeureCourteSontCeuxDuSite(iso: String, courte: String, jour: String) throws {
    let date = try #require(ISO8601DateFormatter().date(from: iso))
    #expect(FormatsDuSite.dateHeureCourte(date) == courte)
    #expect(FormatsDuSite.jourISO(date) == jour)
}

// MARK: - Reporting

@Test func leSuiviLitLeReleveDeSonMode() {
    #expect(ReleveSuivi(mode: "suivi") == .affaires)
    #expect(ReleveSuivi(mode: "relance") == .affaires, "la relance lit le relevé du Suivi affaires")
    #expect(ReleveSuivi(mode: "entretien") == .entretien)
    #expect(TablesReporting.modes.map(\.code) == ["suivi", "entretien", "relance"])
}

@Test func lAgeEtLEvolutionDUneAffaireSuiventLesTablesDuSite() async throws {
    let suivi = try await ServiceSimule(delai: .zero).suiviAffaires(.affaires, dans: ServiceSimule.residence)
    let ancienne = try #require(suivi.affaires.first)
    #expect(ancienne.anciennete == "ancienne" && ancienne.teinteAge == "badge-red")
    #expect(ancienne.evolution == "Nouveau message depuis le dernier résumé")
    var inconnue = ancienne
    inconnue.motifEvolution = "fusion"
    #expect(inconnue.evolution == TablesReporting.motifEvolutionParDefaut)
    #expect(TextesReporting.nonFermees(1, entretien: false) == "affaire non fermée")
    #expect(TextesReporting.nonFermees(5, entretien: true) == "entretiens non clos")
    #expect(TextesReporting.anciennes(suivi.delaiJours) == "de plus de 90 jours")
}

/// Reporting › Renouvellements (#56) : le relevé servi, lu par son type généré, rangé
/// sans rien recalculer — l'ordre, l'année et l'état sont ceux du serveur.
@Test func lesRenouvellementsSeLisentTelsQueServis() async throws {
    let lu = Renouvellements(
        try await client(servant: FixturesRenouvellements.releve).getReportingRenouvellements().ok.body.json)
    #expect(lu.annee == 2026 && lu.preavisMois == 3 && lu.contratsEnPreavis == 1 && lu.auditsAPlanifier == 2)
    #expect(lu.contratsDeLAnnee.map(\.id) == [11, 12], "dans l'ordre servi : la pire note d'abord")
    #expect(lu.contratsFuturs.map(\.id) == [13])
    #expect(lu.contratsSansDate.map(\.id) == [14])
    #expect(lu.diagnosticsParAnnee.map(\.annee) == ["2026", "2032"])
    #expect(lu.diagnosticsParAnnee.first?.diagnostics.map(\.urgence) == ["depasse", "annee"])
    #expect(lu.diagnosticsPermanents.map(\.id) == [1])
    let ascenseurs = try #require(lu.contrats.first)
    #expect(TextesRenouvellements.periode(ascenseurs) == "1 déc. 2023 → 30 nov. 2026 · préavis dès 31 août 2026")
    #expect(TextesRenouvellements.note(ascenseurs) == "★ 2,5 (4 avis)")
    #expect(TextesRenouvellements.note(lu.contrats[3]) == nil, "sans note, rien")
    #expect(try await ServiceSimule(delai: .zero).renouvellements(ServiceSimule.residence) == lu)
}

@Test func chaqueTeinteDeTrancheAUneCouleur() {
    for teinte in ["s1", "s8", "p1", "p4", "autre"] {
        #expect(TablesReporting.tranches[teinte]?.count == 1, "\(teinte) : un aplat")
    }
    #expect(TablesReporting.tranches["plusieurs"]?.count == 2, "plusieurs : des hachures")
}

// MARK: - Annonces Hall

/// `GET /annonces-hall` est typé (`AnnonceHallRead`) et sert ses gestes : « Restaurer »
/// seulement pour une affiche rangée à la main, « Supprimer » à l'administrateur (#56).
@Test func uneAfficheSeLitParSonTypeEtPorteSesGestes() async throws {
    let lues = try await client(servant: FixturesAnnoncesHall.affiches).getAnnoncesHall(query: .init()).ok.body.json
        .map(AnnonceHall.init)
    let enCours = try #require(lues.first { $0.id == 7 })
    #expect(enCours.formatLabel == "A5" && enCours.envoyeLe != nil)
    #expect(enCours.peutArchiver && !enCours.peutRestaurer)
    let rangeeALaMain = try #require(lues.first { $0.id == 4 })
    #expect(rangeeALaMain.archivee && rangeeALaMain.peutRestaurer)
    let rangeeParLeTemps = try #require(lues.first { $0.id == 3 })
    #expect(rangeeParLeTemps.archivee && !rangeeParLeTemps.peutRestaurer && !rangeeParLeTemps.peutArchiver)
    #expect(lues.allSatisfy { $0.peutSupprimer }, "servi à l'administrateur")
}

@Test func uneAfficheDemandeUnTitreEtUnMessage() {
    var saisie = SaisieAnnonceHall()
    #expect(!saisie.complete && saisie.format == "auto")
    #expect(!saisie.envoyerCS && !saisie.envoyerSyndic && !saisie.envoyerAuteur, "aucun envoi par défaut")
    saisie.titre = "Coupure d'eau"
    saisie.message = "  "
    #expect(!saisie.complete)
    saisie.message = "Jeudi matin."
    #expect(saisie.complete)
}

@Test func lesGestesSimulesDesAffichesChangentLaListe() async throws {
    let service = ServiceSimule(delai: .zero)
    let residence = ServiceSimule.residence
    let enCours = try await service.annoncesHall(archivees: false, dans: residence)
    let premiere = try #require(enCours.first)
    try await service.archiverAnnonceHall(premiere.id, archivee: true, dans: residence)
    #expect(try await service.annoncesHall(archivees: true, dans: residence).contains { $0.id == premiere.id })
    var saisie = SaisieAnnonceHall(titre: "Essai", message: "Un message")
    saisie.envoyerCS = true
    let creee = try await service.creerAnnonceHall(saisie, dans: residence)
    #expect(TextesAnnoncesHall.creee(creee).hasPrefix("Annonce A5 créée et envoyée à 2 membres du CS"))
    try await service.supprimerAnnonceHall(creee.id, dans: residence)
    #expect(try await !service.annoncesHall(archivees: false, dans: residence).contains { $0.id == creee.id })
}

// MARK: - Courriels affaires

@Test func leVerdictDUnMessageEstCeluiDuSite() async throws {
    #expect(TablesCourriels.verdicts["refuse"] == LibelleTeinte("Refusé", "badge-orange"))
    let journal = try await ServiceSimule(delai: .zero).journalCourriels(ServiceSimule.residence)
    let refuse = try #require(journal.messages.first { $0.decision == "refuse" })
    #expect(refuse.verdict.libelle == "Refusé")
    var inconnu = refuse
    inconnu.decision = "en_file"
    #expect(inconnu.verdict == .brut("en_file"))
    #expect(TextesCourriels.aide(journal.limite).hasPrefix("Les 50 derniers messages"))
}
