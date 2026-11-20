// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

/// Signaler une affaire, une suite ou la réponse de l'assistant ; masquer ce que publie un
/// résident (#286, coprofirst#2861). Au-dessus du plancher : derrière la porte
/// `VersionContrat.moderation`, générée avec les routes `/masquages`.
@MainActor
struct ModerationTests {
    private func residence(contrat: String?) -> Installation {
        var installation = ServiceSimule.residence
        installation.versionContrat = contrat
        return installation
    }

    @Test func lesDeuxServicesRealisentLesMasquages() {
        let _: any ServiceMasquages = ServiceAPI()
        let _: any ServiceMasquages = ServiceSimule()
        #expect(ServiceSimule().masquages != nil && ServiceSimule().signalements != nil)
    }

    /// La porte s'ouvre à la version du contrat qui sert les routes, pas avant ; un contrat
    /// absent ou illisible garde les gestes du plancher.
    @Test func laPorteSuitLeContratServi() {
        #expect(VersionContrat.moderation > .plancher, "au-dessus du plancher, sinon la déclaration se retire")
        #expect(residence(contrat: VersionContrat.moderation.description).sert(.moderation))
        #expect(residence(contrat: "99.0.0").sert(.moderation))
        #expect(!residence(contrat: VersionContrat.plancher.description).sert(.moderation))
        #expect(!residence(contrat: nil).sert(.moderation))
        #expect(!residence(contrat: "2.x").sert(.moderation))
    }

    @Test func lesCiblesSontCellesDuSite() {
        #expect(CibleSignalement.affaire(4).type == "affaire")
        #expect(CibleSignalement.suite(5).type == "suite")
        #expect(CibleSignalement.questionReglement(6) == CibleSignalement(type: "question_reglement", id: 6))
    }

    // MARK: - 🚩 sur une affaire

    private func affaire(_ droits: DroitsServisAffaire, archivee: Bool = false) -> DetailAffaire {
        DetailAffaire(
            id: 41, numero: "A-0041", titre: "T", description: "", categorie: "plomberie", statut: "en_cours",
            urgente: false, creeLe: .now, auteur: nil, lieu: nil, suites: [], droits: droits,
            archivee: archivee, fusionnee: false, referentiels: (try? FixturesReferentielsAffaires.lus()) ?? .vides)
    }

    /// `!peutCorriger && !archive` d'`ActionsTicket.svelte`, après 🔗.
    @Test func leDrapeauSOffreAQuiLaLitSansLaCorriger() {
        let lecteur = affaire(.init(repondre: true))
        #expect(GesteAffaire.offerts(pour: lecteur, conseil: false, moderation: true) == [.lien, .signaler, .repondre])
        #expect(!GesteAffaire.offerts(pour: lecteur, conseil: false).contains(.signaler), "porte fermée : rien")
        let auteur = affaire(.init(corriger: true))
        #expect(!GesteAffaire.offerts(pour: auteur, conseil: false, moderation: true).contains(.signaler))
        let archivee = affaire(.init(), archivee: true)
        #expect(!GesteAffaire.offerts(pour: archivee, conseil: false, moderation: true).contains(.signaler))
    }

    // MARK: - 🚩 et 🙈 sur une suite

    private func suite(contenu: String? = "Un mot.", auteurId: Int? = 31, auteur: String? = "Dominique EXEMPLE")
        -> SuiteAffaire {
        SuiteAffaire(
            id: 9, type: "commentaire", date: .now, auteur: auteur, contenu: contenu, ancienStatut: nil,
            nouveauStatut: nil, auteurId: auteurId)
    }

    /// `peutSignaler` de `RubriqueHistorique.svelte` : un texte, écrit par un autre ; masquer
    /// exige un auteur nommé. Sans le compte (`moi`) ni la porte : rien.
    @Test func uneSuiteDUnAutreSeSignaleEtSonAuteurSeMasque() {
        #expect(GesteSuite.offerts(pour: suite(), moi: 7, moderation: true) == [.signaler, .masquer])
        #expect(GesteSuite.offerts(pour: suite(auteur: nil), moi: 7, moderation: true) == [.signaler])
        #expect(GesteSuite.offerts(pour: suite(auteurId: 7), moi: 7, moderation: true).isEmpty, "la sienne")
        #expect(GesteSuite.offerts(pour: suite(contenu: nil), moi: 7, moderation: true).isEmpty, "sans texte")
        #expect(GesteSuite.offerts(pour: suite(contenu: ""), moi: 7, moderation: true).isEmpty)
        #expect(GesteSuite.offerts(pour: suite(), moi: nil, moderation: true).isEmpty, "compte inconnu")
        #expect(GesteSuite.offerts(pour: suite(), moi: 7, moderation: false).isEmpty, "porte fermée")
        #expect(GesteSuite.masquer.libelle(pour: suite()) == "Masquer ce que publie Dominique EXEMPLE")
    }

    @Test func lAuteurDUneSuiteServieSeLit() throws {
        let json = #"""
            [{"id": 2, "ticket_id": 41, "type": "commentaire", "auteur_id": 31, "auteur_nom": "Dominique EXEMPLE",
              "nouveau_statut_libelle": "", "perimetre_precise_libelle": "", "etat_propose_libelle": "",
              "cree_le": "2026-11-09T11:00:00", "contenu": "Un mot."}]
            """#
        let lue = try Relecture.generee([Components.Schemas.TicketEvolutionRead].self, json: json)
            .map(SuiteAffaire.init(evolution:))
        #expect(lue.first?.auteurId == 31)
    }

    // MARK: - Masquer

    @Test func onNeMasqueNiSoiNiUnAnonyme() {
        #expect(AuteurAMasquer(id: 31, nom: "Dominique EXEMPLE", moi: 7)?.nom == "Dominique EXEMPLE")
        #expect(AuteurAMasquer(id: 7, nom: "Moi", moi: 7) == nil)
        #expect(AuteurAMasquer(id: nil, nom: "X", moi: 7) == nil)
        #expect(AuteurAMasquer(id: 31, nom: nil, moi: 7) == nil)
        #expect(AuteurAMasquer(id: 31, nom: "", moi: 7) == nil)
    }

    /// L'API simulée tient sa liste comme le serveur : masquer deux fois n'en pose qu'un.
    @Test func laListeSimuleeSeTientCommeLeServeur() async throws {
        let service = ServiceSimule()
        let installation = residence(contrat: VersionContrat.moderation.description)
        #expect(try await service.masques(dans: installation).map(\.auteur) == ["Dominique EXEMPLE"])
        let camille = try #require(AuteurAMasquer(id: 32, nom: "Camille ESSAI", moi: 7))
        try await service.masquer(camille, dans: installation)
        try await service.masquer(camille, dans: installation)
        #expect(try await service.masques(dans: installation).map(\.auteurId) == [31, 32])
        try await service.demasquer(31, dans: installation)
        #expect(try await service.masques(dans: installation).map(\.auteurId) == [32])
    }

    @Test func lesMotsSontCeuxDuSite() {
        #expect(TextesMasquage.question("Camille ESSAI") == "Masquer ce que publie Camille ESSAI ?")
        #expect(TextesMasquage.masque("Camille ESSAI") == "Ce que publie Camille ESSAI est masqué pour vous")
        #expect(TextesMasquage.demasque("Camille ESSAI") == "Vous voyez de nouveau ce que publie Camille ESSAI")
    }
}
