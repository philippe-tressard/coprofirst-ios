// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import ClientAPI

/// Un champ servi au-dessus du plancher : le type généré l'ignore, le corps gardé le porte.
private let servi = #"{"status":"ok","gestes_roles":{"admin":"ajouter"}}"#

private func client(_ corps: String) -> Client {
    ClientCoproFirst.client(
        installation: URL(string: "https://demo.coprofirst.fr")!,
        transport: TransportEnregistreur(statut: .ok, corps: corps))
}

@Test func garderRendLeCorpsServiEtLaSortieGeneree() async throws {
    let (sortie, corps) = try await CorpsServi.garder { try await client(servi).getHealth() }
    _ = try sortie.ok.body.json
    #expect(corps == Data(servi.utf8))
}

@Test func horsDeGarderRienNEstGarde() async throws {
    _ = try await client(servi).getHealth().ok.body.json
    #expect(CorpsServi.recueil == nil)
}

/// Deux appels concurrents : chacun garde SON corps, jamais celui de l'autre.
@Test func chaqueAppelGardeSonPropreCorps() async throws {
    async let premier = CorpsServi.garder { try await client(#"{"status":"un"}"#).getHealth() }
    async let second = CorpsServi.garder { try await client(#"{"status":"deux"}"#).getHealth() }
    let (un, deux) = try await (premier.corps, second.corps)
    #expect(un == Data(#"{"status":"un"}"#.utf8))
    #expect(deux == Data(#"{"status":"deux"}"#.utf8))
}

/// Deux réponses à la suite : la première, puis la réponse rejouée.
private final class TransportSuccessif: ClientTransport, @unchecked Sendable {
    private let verrou = NSLock()
    private var corps: [String]

    init(_ corps: [String]) { self.corps = corps }

    func send(
        _ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let suivant = verrou.withLock { corps.removeFirst() }
        var reponse = HTTPResponse(status: .ok)
        reponse.headerFields[.contentType] = "application/json"
        return (reponse, HTTPBody(suivant))
    }
}

/// Un intercepteur de l'app qui rejoue la requête (le renouvellement sur 401, #81).
private struct Rejouer: ClientMiddleware {
    func intercept(
        _ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        _ = try await next(request, body, baseURL)
        return try await next(request, body, baseURL)
    }
}

/// Après un rejeu par un intercepteur de l'app, le corps gardé est celui de la réponse
/// FINALE — jamais la première.
@Test func garderRendLeCorpsDeLaReponseRejouee() async throws {
    let rejoue = ClientCoproFirst.client(
        installation: URL(string: "https://demo.coprofirst.fr")!,
        transport: TransportSuccessif([#"{"status":"refus"}"#, #"{"status":"rejoue"}"#]), middlewares: [Rejouer()])
    let (_, corps) = try await CorpsServi.garder { try await rejoue.getHealth() }
    #expect(corps == Data(#"{"status":"rejoue"}"#.utf8))
}
