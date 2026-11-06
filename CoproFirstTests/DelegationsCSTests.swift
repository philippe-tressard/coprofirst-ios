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
    let conseil = ProfilResidence(statut: "copropriétaire_résident", roles: ["propriétaire", "conseil_syndical"])
    #expect(PagesOuvertes.ouverte("delegations", droits: DroitsOnglet(profil: conseil)))
}

// MARK: - Délégations

/// Le JSON de `_to_read` (`routers/delegations.py`, v3.61.0) : la route n'a pas de
/// `response_model`, l'app le relit en miroir.
@Test func uneDelegationSeRelitTelleQueLeServeurLaSert() throws {
    let json = #"""
        [{"id": 12, "mandant_id": 3, "mandant_nom": "Lucie Exemple", "aidant_id": 7, "aidant_nom": "Camille Essai",
          "statut": "en_attente", "motif": "", "date_debut": "2026-11-02", "date_fin": null,
          "cree_le": "2026-11-02T09:00:00", "revoque_le": null}]
        """#
    let delegation = try #require(try Relecture.lire([Delegation].self, json: Data(json.utf8)).first)
    #expect(delegation.mandantNom == "Lucie Exemple" && delegation.aidantId == 7)
    #expect(delegation.dateFin == nil)
    #expect(TextesDelegations.periode(delegation) == "Du 02/11/2026 — illimité")
}

@Test func seulLAidantAccepteUneDelegationEnAttente() {
    let enAttente = Delegation(
        id: 1, mandantId: 3, mandantNom: "A", aidantId: 7, aidantNom: "B", statut: "en_attente", motif: "",
        dateDebut: "2026-04-02", dateFin: "2026-06-30")
    #expect(enAttente.acceptable(par: 7))
    #expect(!enAttente.acceptable(par: 3), "la personne aidée n'accepte pas pour l'aidant")
    var active = enAttente
    active.statut = "active"
    #expect(!active.acceptable(par: 7))
    #expect(enAttente.revocable && active.revocable)
    for fini in ["revoquee", "expiree"] {
        var terminee = enAttente
        terminee.statut = fini
        #expect(!terminee.revocable)
    }
    #expect(TextesDelegations.periode(enAttente) == "Du 02/04/2026 au 30/06/2026")
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
    let enAttente = try #require(avant.delegations.first { $0.acceptable(par: avant.moi) })
    #expect(try await service.accepterDelegation(enAttente.id, dans: residence).statut == "active")
    await #expect(throws: ErreurService.self) { try await service.accepterDelegation(enAttente.id, dans: residence) }
    #expect(try await service.revoquerDelegation(enAttente.id, dans: residence).statut == "revoquee")
    var saisie = SaisieDelegation(mandant: 4, aidant: 7, motif: "Essai")
    saisie.dateFin = ISO8601DateFormatter().date(from: "2026-07-25T22:30:00Z")
    let creee = try await service.creerDelegation(saisie, dans: residence)
    #expect(creee.statut == "en_attente" && creee.dateFin == "2026-07-26", "le jour de Paris")
    #expect(try await service.delegations(residence).delegations.first?.id == creee.id)
    // Un autre service simulé garde sa propre liste.
    #expect(try await ServiceSimule(delai: .zero).delegations(residence).delegations.count == avant.delegations.count)
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

@Test func chaqueTeinteDeTrancheAUneCouleur() {
    for teinte in ["s1", "s8", "p1", "p4", "autre"] {
        #expect(TablesReporting.tranches[teinte]?.count == 1, "\(teinte) : un aplat")
    }
    #expect(TablesReporting.tranches["plusieurs"]?.count == 2, "plusieurs : des hachures")
}

// MARK: - Annonces Hall

@Test func uneAfficheSeRelitEtNeSeRestaureQueSiElleAEteArchiveeALaMain() throws {
    let json = #"""
        {"id": 7, "titre": "Coupure d'eau", "message": "<p>Jeudi</p>", "assiste_ia": false, "apercu": "Jeudi",
         "perimetre_cible": ["bat_a"], "perimetre_label": "Bâtiment A", "format_demande": "auto",
         "format_effectif": "a5", "format_label": "A5", "images": [], "pdf_nom": "x.pdf", "taille_octets": 1200,
         "destinataires": [], "envoye_le": null, "archivee": true, "archivee_manuellement": false,
         "ticket_id": null, "cree_le": "2026-09-01T10:00:00", "auteur_nom": "Camille Essai"}
        """#
    var affiche = try Relecture.lire(AnnonceHall.self, json: Data(json.utf8))
    #expect(affiche.formatLabel == "A5" && affiche.envoyeLe == nil)
    #expect(!affiche.archivable, "archivée par le temps : « Restaurer » n'aurait aucun effet")
    affiche.archiveeManuellement = true
    #expect(affiche.archivable)
    affiche.archivee = false
    affiche.archiveeManuellement = false
    #expect(affiche.archivable, "une affiche en cours s'archive")
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
