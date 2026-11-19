// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import HTTPTypes
import Testing

@testable import ClientAPI

/// L'écran de hall lit ses affiches avec SON jeton (`JetonAppareil`, coprofirst#2770) : le
/// client qui le porte le présente en `Bearer` ; un client sans lui ne présente rien.
@Test func leJetonDUnAppareilPartEnBearer() async throws {
    let transport = TransportEnregistreur(statut: .ok, corps: "[]")
    let client = ClientCoproFirst.client(
        installation: URL(string: "https://demo.coprofirst.fr")!, transport: transport,
        middlewares: [JetonAppareil("jeton-d-essai")])

    _ = try await client.getEcransMoiAffiches().ok

    let (requete, _) = try #require(transport.requetes.first)
    #expect(requete.path == "/ecrans/moi/affiches")
    #expect(requete.headerFields[.authorization] == "Bearer jeton-d-essai")
}

@Test func unClientSansJetonNePresenteRien() async throws {
    let transport = TransportEnregistreur(statut: .ok, corps: "[]")
    let client = ClientCoproFirst.client(installation: URL(string: "https://demo.coprofirst.fr")!, transport: transport)

    _ = try await client.getEcransMoiAffiches().ok

    let (requete, _) = try #require(transport.requetes.first)
    #expect(requete.headerFields[.authorization] == nil)
}
