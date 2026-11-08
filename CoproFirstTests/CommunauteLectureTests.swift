// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import CoproFirst

// 🔴 Bogue du 06/11/2026 (iPhone, installation réelle) : « Impossible d'afficher les
// idées » et les annonces. Le contrat 1.5.0 type `/idees` et `/annonces` ; le service
// relisait la réponse typée par `Relecture`, qui réencodait `cree_le` en NOMBRE — le
// décodage échouait. Les tests passaient : la simulation construisait ses `Idee` à la
// main. Ici, la réponse du serveur traverse le client GÉNÉRÉ (son transcodeur de dates
// compris) puis le branchement du service, sans réseau.

/// Un transport qui sert un corps JSON fixe, quelle que soit la route.
private struct TransportFixe: ClientTransport {
    let corps: String

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws
        -> (HTTPResponse, HTTPBody?) {
        var reponse = HTTPResponse(status: .ok)
        reponse.headerFields[.contentType] = "application/json"
        return (reponse, HTTPBody(corps))
    }
}

private func client(servant corps: String) -> Client {
    ClientCoproFirst.client(installation: URL(string: "https://demo.exemple")!, transport: TransportFixe(corps: corps))
}

private func date(_ texte: String) -> Date? { ISO8601DateFormatter().date(from: texte + "Z") }

@Test func lesIdeesServiesSeLisentAvecLeursDates() async throws {
    let idees = try await client(servant: FixturesCommunaute.idees).getIdees().ok.body.json.map(Idee.init)
    #expect(idees.map(\.id) == [3, 5, 1])
    #expect(idees.first?.creeLe == date("2026-10-25T09:30:00"), "sans fuseau = UTC")
    #expect(idees.first?.reponses?.first?.creeLe == date("2026-10-26T18:00:00"))
    #expect(idees.first?.monVote == true && idees.first?.nbVotes == 18)
}

@Test func lesAnnoncesServiesSeLisentAvecLeursDates() async throws {
    let annonces = try await client(servant: FixturesCommunaute.annonces).getAnnonces().ok.body.json
        .map(Annonce.init)
    #expect(annonces.map(\.id) == [21, 22, 23])
    #expect(annonces.first?.creeLe == date("2026-11-04T10:00:00"))
    #expect(annonces.first?.reponses?.first?.creeLe == date("2026-11-05T18:00:00"))
}

/// L'API simulée sert ce que le service réel lirait des mêmes octets : un écart de
/// lecture entre les deux chemins ne peut plus rester invisible.
@Test func laSimulationLitCommeLeServiceReel() async throws {
    let simule = ServiceSimule(delai: .zero)
    let installation = ServiceSimule.demo
    let lues = try await client(servant: FixturesCommunaute.idees).getIdees().ok.body.json.map(Idee.init)
    #expect(try await simule.idees(installation) == lues)
    let annonces = try await client(servant: FixturesCommunaute.annonces).getAnnonces().ok.body.json
        .map(Annonce.init)
    #expect(try await simule.annonces(installation) == annonces)
}
