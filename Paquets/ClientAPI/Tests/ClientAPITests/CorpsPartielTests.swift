// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import ClientAPI

/// Un PATCH partiel ne porte QUE ses champs : un champ absent n'est pas envoyé à `null`.
///
/// Le serveur applique un `null` reçu : un PATCH /tickets/{id} d'archivage qui porterait
/// `affaires_liees: null` effacerait les affaires liées et « Saisi pour » (constaté côté
/// Android, coprofirst-android#99, 15/11/2026). Ces tests passent par le client généré,
/// jusqu'au corps réellement envoyé.
private final class TransportCorpsPartiel: ClientTransport, @unchecked Sendable {
    private let verrou = NSLock()
    private var lus: [Data] = []
    var corps: [Data] { verrou.withLock { lus } }

    func send(
        _ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var donnees = Data()
        if let body { donnees = try await Data(collecting: body, upTo: 1 << 20) }
        verrou.withLock { lus.append(donnees) }
        return (HTTPResponse(status: .noContent), nil)
    }
}

private func envoye(_ corps: Components.Schemas.TicketUpdate) async throws -> [String: Any] {
    let transport = TransportCorpsPartiel()
    let client = ClientCoproFirst.client(installation: URL(string: "https://demo.coprofirst.fr")!, transport: transport)
    _ = try? await client.patchTicketsTicketId(path: .init(ticketId: 41), body: .json(corps))
    let donnees = try #require(transport.corps.first)
    return try #require(try JSONSerialization.jsonObject(with: donnees) as? [String: Any])
}

@Test func archiverNEnvoieQueLArchivage() async throws {
    let corps = try await envoye(.init(archiveManuel: true))
    #expect(Array(corps.keys) == ["archive_manuel"], "aucune autre clé, pas même à null : \(corps)")
    #expect(corps["archive_manuel"] as? Bool == true)
}

@Test func epinglerNEnvoieQueLEpingle() async throws {
    let corps = try await envoye(.init(epingle: false))
    #expect(Array(corps.keys) == ["epingle"], "\(corps)")
}

@Test func aucunChampAbsentNePartANull() async throws {
    let corps = try await envoye(.init(titre: "Fuite", urgente: true))
    #expect(Set(corps.keys) == ["titre", "urgente"], "\(corps)")
    #expect(!corps.values.contains { $0 is NSNull }, "aucune valeur null : \(corps)")
}
