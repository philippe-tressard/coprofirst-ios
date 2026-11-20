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

    @Test func laBulleDitVousPourLeCompteEtLeNomServiSinon() throws {
        let lus = try FixturesMessagesAffaire.lus(pour: 41, conseil: false)
        #expect(lus.first?.deMoi == true && lus.first?.auteur == "Vous")
        #expect(lus.last?.deMoi == false && lus.last?.auteur == "Le conseil syndical")
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
        let sortie = try await filServi(FixturesMessagesAffaire.messages)
        let lus = MessageAffaire.lus(try sortie.ok.body.json)
        #expect(lus.map(\.id) == [501, 502, 503] && lus[0].deMoi && lus[2].interne)
        #expect(lus.map(\.nom) == ["Camille ESSAI", "Le conseil syndical", "Le conseil syndical"])
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

    // MARK: - #211 : modifier, retirer SON message

    /// La règle du site et de la route : son auteur (`est_auteur`), tant que l'affaire n'est
    /// pas close ; « Modifier » seulement si l'app sait réécrire le texte sans rien perdre.
    @Test func sesGestesSontCeuxDeLAuteurTantQueLAffaireEstOuverte() throws {
        var affaire = try ServiceSimule(delai: .zero).detailSimule(41)
        let lus = try FixturesMessagesAffaire.lus(pour: 41, conseil: true)
        let (mien, autre) = (lus[0], lus[1])
        #expect(GesteMessage.offerts(pour: mien, dans: affaire) == [.modifier, .supprimer])
        #expect(GesteMessage.offerts(pour: autre, dans: affaire).isEmpty, "le message d'un autre")
        let enGras = MessageAffaire(
            id: 9, contenu: "<p>Le <strong>plombier</strong>.</p>", date: .now, deMoi: true, nom: nil, qualite: nil,
            interne: false, pieces: .aucune)
        #expect(GesteMessage.offerts(pour: enGras, dans: affaire) == [.supprimer], "sa mise en forme reste au site")
        affaire.close = true
        #expect(GesteMessage.offerts(pour: mien, dans: affaire).isEmpty, "une affaire close")
    }

    /// Le faux serveur fait ce que fait le vrai : le message ET son miroir de l'Historique.
    @Test func modifierPuisRetirerSonMessageSuitLeMiroir() async throws {
        let service = ServiceSimule(delai: .zero)
        service.profilSimule = resident
        try await service.repondre("Ça goutte encore.", a: 41, dans: ServiceSimule.residence)
        let envoye = try #require(try service.detailSimule(41).messages.last)

        try await service.corrigerMessage("<p>Ça ne goutte plus.</p>", envoye.id, de: 41, dans: ServiceSimule.residence)
        var apres = try service.detailSimule(41)
        #expect(apres.messages.last?.contenu == "<p>Ça ne goutte plus.</p>")
        #expect(apres.suites.last?.type == "reponse" && apres.suites.last?.contenu == "<p>Ça ne goutte plus.</p>")

        try await service.supprimerMessage(envoye.id, de: 41, dans: ServiceSimule.residence)
        apres = try service.detailSimule(41)
        #expect(!apres.messages.contains { $0.id == envoye.id })
        #expect(!apres.suites.contains { $0.contenu == "<p>Ça ne goutte plus.</p>" }, "le miroir part avec lui")
        await #expect(throws: ErreurService.self, "le message d'un autre : refusé") {
            try await service.supprimerMessage(502, de: 41, dans: ServiceSimule.residence)
        }
    }

    /// Les routes et le corps : PATCH …/messages/{id} avec le seul texte, DELETE …/messages/{id}.
    @Test func lesDeuxGestesPassentParLesRoutesDuMessage() async throws {
        let modifie = Enregistrement()
        let transport = TransportEnregistreur(modifie, statut: .ok)
        try await ServiceAPI(transport: { _ in transport })
            .corrigerMessage("<p>Un mot.</p>", 501, de: 41, dans: ServiceSimule.residence)
        #expect(modifie.requete?.method == .patch)
        #expect(modifie.adresse?.hasSuffix("/tickets/41/messages/501") == true)
        let corps = try JSONDecoder().decode([String: String].self, from: try #require(modifie.corps))
        #expect(corps == ["contenu": "<p>Un mot.</p>"], "les pièces jointes ne partent pas : le serveur les garde")

        let retire = Enregistrement()
        let transportRetrait = TransportEnregistreur(retire, statut: .noContent)
        try await ServiceAPI(transport: { _ in transportRetrait })
            .supprimerMessage(501, de: 41, dans: ServiceSimule.residence)
        #expect(retire.requete?.method == .delete)
        #expect(retire.adresse?.hasSuffix("/tickets/41/messages/501") == true)
    }
}

/// GET /tickets/41/messages par le client généré — hors de l'acteur principal, comme le
/// service réel.
private func filServi(_ json: String) async throws -> Operations.GetTicketsTicketIdMessages.Output {
    try await client(servant: json).getTicketsTicketIdMessages(path: .init(ticketId: 41))
}

/// Ce que le client a envoyé, retenu pour le test.
private final class Enregistrement: @unchecked Sendable {
    var requete: HTTPRequest?
    var adresse: String?
    var corps: Data?
}

/// Un serveur qui retient la requête et répond `statut` (201 par défaut) avec un `MessageRead` —
/// sans corps pour 204.
private struct TransportEnregistreur: ClientTransport {
    let enregistrement: Enregistrement
    let statut: HTTPResponse.Status
    init(_ enregistrement: Enregistrement, statut: HTTPResponse.Status = .created) {
        self.enregistrement = enregistrement
        self.statut = statut
    }

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws
        -> (HTTPResponse, HTTPBody?) {
        enregistrement.requete = request
        enregistrement.adresse = request.path
        if let body { enregistrement.corps = try await Data(collecting: body, upTo: 1 << 16) }
        var reponse = HTTPResponse(status: statut)
        guard statut != .noContent else { return (reponse, nil) }
        reponse.headerFields[.contentType] = "application/json"
        let servi = #"""
            {"id": 9, "ticket_id": 41, "contenu": "<p>Merci</p>", "interne": false, "cree_le": "2026-11-10T09:00:00"}
            """#
        return (reponse, HTTPBody(servi))
    }
}
