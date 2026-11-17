// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import ClientAPI

/// Un transport qui garde le corps de chaque requête.
private final class TransportCorps: ClientTransport, @unchecked Sendable {
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

private struct ChampsAjoutes: Encodable {
    let prestataireIds: [Int]
}

private func objet(_ donnees: Data) throws -> [String: Any] {
    try #require(try JSONSerialization.jsonObject(with: donnees) as? [String: Any])
}

private func modifier(_ client: Client, _ corps: Components.Schemas.TicketUpdate) async throws {
    _ = try? await client.patchTicketsTicketId(path: .init(ticketId: 41), body: .json(corps))
}

@Test func completerAjouteLeChampAuCorpsGenere() async throws {
    let transport = TransportCorps()
    let client = ClientCoproFirst.client(installation: URL(string: "https://demo.coprofirst.fr")!, transport: transport)
    try await CorpsEnvoye.completer(avec: ChampsAjoutes(prestataireIds: [3, 1])) {
        try await modifier(client, .init(titre: "Fuite"))
    }
    let envoye = try objet(try #require(transport.corps.first))
    #expect(envoye["titre"] as? String == "Fuite")
    #expect(envoye["prestataire_ids"] as? [Int] == [3, 1])
}

@Test func horsDeCompleterLeCorpsPartTelQuel() async throws {
    let transport = TransportCorps()
    let client = ClientCoproFirst.client(installation: URL(string: "https://demo.coprofirst.fr")!, transport: transport)
    try await modifier(client, .init(titre: "Fuite"))
    let envoye = try objet(try #require(transport.corps.first))
    #expect(envoye["prestataire_ids"] == nil)
    #expect(CorpsEnvoye.ajouts == nil)
}

/// Le corps généré porte déjà le champ : l'ajout ne le remplace jamais, l'appel échoue.
@Test func unChampDejaPorteNEstJamaisRemplace() throws {
    #expect(throws: CorpsEnvoye.Collision(champ: "titre")) {
        try CorpsEnvoye.reunir(Data(#"{"titre":"A"}"#.utf8), Data(#"{"titre":"B"}"#.utf8))
    }
}

/// Un `null` EXPLICITE (#207) : le type généré tait un champ `nil`, et un serveur qui ne
/// lit que les champs envoyés ne l'efface donc jamais. Ajouté par `completer`, il part.
@Test func unNulExplicitePartAvecLeCorpsGenere() async throws {
    let transport = TransportCorps()
    let client = ClientCoproFirst.client(installation: URL(string: "https://demo.coprofirst.fr")!, transport: transport)
    let corps = Components.Schemas.NotationUpdate(etat: .neutre)
    let nuls: [String: Int?] = ["ticket_id": nil]
    try await CorpsEnvoye.completer(avec: nuls) {
        _ = try? await client.patchPrestatairesNotationsNId(path: .init(nId: 12), body: .json(corps))
    }
    let envoye = try objet(try #require(transport.corps.first))
    #expect(envoye["etat"] as? String == "neutre")
    #expect(envoye["ticket_id"] is NSNull)
    #expect(envoye.keys.contains("commentaire") == false)
}
