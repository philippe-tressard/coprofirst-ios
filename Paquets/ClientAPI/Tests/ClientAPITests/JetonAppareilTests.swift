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

/// Le jeton ne s'écrit jamais (#342) : ni l'enveloppe, ni l'intercepteur, ni un type qui la
/// garde ne le laissent paraître — description, reflet, `dump`, interpolation.
@Test func leJetonNeSEcritJamais() {
    struct Porteur { let jeton: JetonMasque }
    let jeton = JetonMasque("brut-secret-789")
    let porteurs: [Any] = [jeton, JetonAppareil(jeton), Porteur(jeton: jeton), [jeton], Optional(jeton) as Any]
    for porteur in porteurs {
        var vidage = ""
        dump(porteur, to: &vidage)
        for texte in ["\(porteur)", String(reflecting: porteur), vidage] {
            #expect(!texte.contains("brut-secret"), "le jeton paraît dans « \(texte.prefix(80)) »")
        }
    }
    #expect(jeton.enClair == "brut-secret-789")
}

/// Encodé, le jeton est son texte seul : une liaison ou un appairage déjà rangé au Trousseau,
/// écrit quand le jeton était une chaîne, se relit à l'identique.
@Test func leJetonSEncodeEnTexteSeul() throws {
    struct Rangee: Codable, Equatable { let jeton: JetonMasque }
    let ancien = Data(#"{"jeton":"abc"}"#.utf8)
    #expect(try JSONDecoder().decode(Rangee.self, from: ancien) == Rangee(jeton: "abc"))
    #expect(try JSONEncoder().encode(Rangee(jeton: "abc")) == ancien)
}
