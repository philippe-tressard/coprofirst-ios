// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import ClientAPI

/// Un transport qui n'atteint aucun réseau : il note la requête et rend une réponse fixe.
private final class TransportEnregistreur: ClientTransport, @unchecked Sendable {
    private(set) var requetes: [(HTTPRequest, URL)] = []
    let statut: HTTPResponse.Status
    let corps: String

    init(statut: HTTPResponse.Status, corps: String) {
        self.statut = statut
        self.corps = corps
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        requetes.append((request, baseURL))
        var reponse = HTTPResponse(status: statut)
        reponse.headerFields[.contentType] = "application/json"
        return (reponse, HTTPBody(corps))
    }
}

@Test func lAdresseDeLAPISeTrouveSousLePrefixeApi() {
    let installation = URL(string: "https://demo.coprofirst.fr")!
    #expect(
        ClientCoproFirst.adresseAPI(installation: installation).absoluteString
            == "https://demo.coprofirst.fr/api/"
    )
}

@Test func leClientGenereAppelleLaSondeDeSante() async throws {
    let transport = TransportEnregistreur(statut: .ok, corps: #"{"status":"ok"}"#)
    let client = ClientCoproFirst.client(
        installation: URL(string: "https://demo.coprofirst.fr")!,
        transport: transport
    )

    let reponse = try await client.healthHealthGet()

    _ = try reponse.ok
    let (requete, base) = try #require(transport.requetes.first)
    #expect(requete.method == .get)
    #expect(requete.path == "/health")
    #expect(base.absoluteString == "https://demo.coprofirst.fr/api/")
}
