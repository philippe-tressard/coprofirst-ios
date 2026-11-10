// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import CoproFirst

/// « Répondre » écrit un MESSAGE (POST /tickets/{id}/messages), comme le site — pas une
/// suite de l'Historique ; le fil des messages se lit sous l'Historique.
@MainActor
struct MessagesAffaireTests {
    private let resident = ProfilResidence(statut: "copropriétaire_résident", roles: ["résident"])

    @Test func leFilSimuleSertLesNotesInternesAuConseilSeulement() throws {
        let auConseil = try FixturesMessagesAffaire.lus(pour: 41, conseil: true)
        let auResident = try FixturesMessagesAffaire.lus(pour: 41, conseil: false)
        #expect(auConseil.map(\.id) == [501, 502, 503])
        #expect(auResident.map(\.id) == [501, 502])
        #expect(try FixturesMessagesAffaire.lus(pour: 38, conseil: true).isEmpty)
    }

    @Test func laBulleDitVousPourLeCompteEtLaQualiteSinon() throws {
        let lus = try FixturesMessagesAffaire.lus(pour: 41, conseil: false)
        #expect(lus.first?.deMoi == true && lus.first?.auteur == "Vous")
        #expect(lus.last?.deMoi == false && lus.last?.auteur == "Le conseil syndical")
        let servi = try Relecture.generee([MessageAffaire.Servi].self, json: FixturesMessagesAffaire.messages)
        let sansCompte = servi.map { MessageAffaire($0, moi: nil) }
        #expect(sansCompte.allSatisfy { !$0.deMoi }, "compte illisible : rien n'est à moi")
    }

    @Test func uneActualiteNaPasDeFilDeMessages() throws {
        #expect(try ServiceSimule(delai: .zero).detailSimule(12).messages.isEmpty)
    }

    @Test func repondreAjouteUnMessageQueLeServeurReporteALHistorique() async throws {
        let service = ServiceSimule(delai: .zero)
        service.profilSimule = resident
        let avant = try service.detailSimule(41)
        #expect(avant.messages.map(\.id) == [501, 502], "un résident ne lit pas la note interne")

        try await service.repondre("Merci, je contourne la zone.", a: 41, dans: ServiceSimule.residence)
        let apres = try service.detailSimule(41)
        let message = try #require(apres.messages.last)
        #expect(apres.messages.count == 3 && message.deMoi && !message.interne)
        #expect(message.contenu == "<p>Merci, je contourne la zone.</p>")
        #expect(apres.suites.last?.type == "reponse" && apres.suites.last?.contenu == message.contenu)
        #expect(!apres.suites.contains { $0.type == "commentaire" && $0.contenu == message.contenu })
    }

    /// Le client généré lit le fil tel que le serveur le sert, puis le branchement du service.
    @Test func leFilServiSeLitParLeClientGenere() async throws {
        let sortie = try await client(servant: FixturesMessagesAffaire.messages)
            .getTicketsTicketIdMessages(path: .init(ticketId: 41))
        let lus = try sortie.ok.body.json.map { MessageAffaire($0, moi: 7) }
        #expect(lus.map(\.id) == [501, 502, 503] && lus[0].deMoi && lus[2].interne)
    }

    /// La route et le corps que « Répondre » envoie : POST …/messages, le texte de l'éditeur.
    @Test func repondrePosteUnMessageEtNonUneEvolution() async throws {
        let enregistrement = Enregistrement()
        let client = ClientCoproFirst.client(
            installation: URL(string: "https://demo.exemple")!, transport: TransportEnregistreur(enregistrement))
        _ = try await client.postTicketsTicketIdMessages(
            path: .init(ticketId: 41), body: .json(ServiceAPI.corpsReponse("Merci\nà demain")))
        let requete = try #require(enregistrement.requete)
        #expect(requete.method == .post)
        #expect(enregistrement.adresse?.hasSuffix("/tickets/41/messages") == true)
        let corps = try JSONDecoder().decode([String: String].self, from: try #require(enregistrement.corps))
        #expect(corps == ["contenu": "<p>Merci<br>à demain</p>"])
    }
}

/// Ce que le client a envoyé, retenu pour le test.
private final class Enregistrement: @unchecked Sendable {
    var requete: HTTPRequest?
    var adresse: String?
    var corps: Data?
}

/// Un serveur qui retient la requête et répond 201 avec un `MessageRead`.
private struct TransportEnregistreur: ClientTransport {
    let enregistrement: Enregistrement
    init(_ enregistrement: Enregistrement) { self.enregistrement = enregistrement }

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws
        -> (HTTPResponse, HTTPBody?) {
        enregistrement.requete = request
        enregistrement.adresse = request.path
        if let body { enregistrement.corps = try await Data(collecting: body, upTo: 1 << 16) }
        var reponse = HTTPResponse(status: .created)
        reponse.headerFields[.contentType] = "application/json"
        let servi = #"""
            {"id": 9, "ticket_id": 41, "contenu": "<p>Merci</p>", "interne": false, "cree_le": "2026-11-10T09:00:00"}
            """#
        return (reponse, HTTPBody(servi))
    }
}
