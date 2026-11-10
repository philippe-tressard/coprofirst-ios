// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// La fiche d'un sondage (#38) : les deux services s'y conforment, le vote attend ce que
/// le site attend, et les gestes simulés changent la fiche comme le serveur.
@Test func lesDeuxServicesServentLaFicheDUnSondage() {
    let reels: [any ServiceSondage] = [ServiceAPI(), ServiceSimule(delai: .zero)]
    #expect(reels.count == 2)
}

@Test func leVoteDitCeQuiManqueDansLOrdreDuSite() {
    var vote = VoteSondage()
    #expect(vote.manque(champLibre: false) == "Sélectionnez une option")
    vote.option = 4
    #expect(vote.manque(champLibre: true) == "Merci de préciser votre réponse dans le champ prévu")
    vote.reponseLibre = "   "
    #expect(
        vote.manque(champLibre: true) == "Merci de préciser votre réponse dans le champ prévu",
        "des blancs ne précisent rien")
    vote.reponseLibre = "Le 20 juin"
    #expect(vote.manque(champLibre: true) == "Vous devez accepter la charte de respect")
    vote.charteAcceptee = true
    #expect(vote.manque(champLibre: true) == nil)
    #expect(VoteSondage.nettoye("  ") == nil && VoteSondage.nettoye(" a ") == "a")
}

@Test func lesPourcentagesEtLesMotsSontCeuxDuSite() {
    #expect(TextesSondage.pourcentage(1, sur: 3) == 33)
    #expect(TextesSondage.pourcentage(2, sur: 3) == 67)
    #expect(TextesSondage.pourcentage(0, sur: 0) == 0, "aucun vote : 0, jamais une division par zéro")
    #expect(TextesSondage.votes(1) == "1 vote" && TextesSondage.votes(12) == "12 votes")
    #expect(TextesSondage.commentaires(3) == "💬 Commentaires (3)")
}

@Test func lesFichesSimuleesSeLisentParLeTypeGenere() throws {
    let fiches = try FixturesSondage.lues()
    let ouverte = try #require(fiches.first { $0.id == 12 })
    #expect(ouverte.peutVoter && ouverte.resultatsVisibles)
    #expect(ouverte.options.last?.champLibre == true && ouverte.options.last?.reponsesLibres.count == 2)
    #expect(ouverte.commentaires.map(\.peutSupprimer) == [false, false, true], "le droit est servi, pas recalculé")
    let masquee = try #require(fiches.first { $0.id == 11 })
    #expect(masquee.options.allSatisfy { $0.nbVotes == nil }, "masqués : absents, jamais 0")
    #expect(fiches.first { $0.id == 9 }?.peutVoter == false)
}

@Test func voterCommenterEtRetirerChangentLaFicheSimulee() async throws {
    let service = ServiceSimule(delai: .zero)
    let residence = ServiceSimule.residence
    let vote = VoteSondage(option: 4, reponseLibre: " Le 20 juin ", commentaire: "Avec plaisir", charteAcceptee: true)
    try await service.voter(vote, au: 12, dans: residence)
    let apres = try await service.sondage(12, dans: residence)
    #expect(apres.monVote == 4 && !apres.peutVoter)
    #expect(apres.options.last?.nbVotes == 3)
    #expect(apres.options.last?.reponsesLibres.last == "Le 20 juin")
    #expect(apres.commentaires.last?.contenu == "Avec plaisir", "le commentaire du vote rejoint le fil")

    await #expect(throws: ErreurService.refus(.init(phrase: "Vous avez déjà voté"))) {
        try await service.voter(vote, au: 12, dans: residence)
    }

    try await service.commenterSondage("Je viendrai", au: 12, dans: residence)
    let commente = try await service.sondage(12, dans: residence)
    let mien = try #require(commente.commentaires.last)
    #expect(mien.contenu == "Je viendrai" && mien.peutSupprimer && mien.auteurId == commente.moi)

    try await service.supprimerCommentaireSondage(mien.id, du: 12, dans: residence)
    #expect(try await service.sondage(12, dans: residence).commentaires.contains { $0.id == mien.id } == false)
    await #expect(throws: ErreurService.self) {
        try await service.supprimerCommentaireSondage(31, du: 12, dans: residence)
    }
}

@Test func unSondageInconnuDesFixturesPrendLaFormeDuPremier() async throws {
    let service = ServiceSimule(delai: .zero)
    let carte = try await service.sondage(3, dans: ServiceSimule.residence)
    #expect(carte.id == 3 && carte.question == "Quel jour pour la fête des voisins ?")
}
