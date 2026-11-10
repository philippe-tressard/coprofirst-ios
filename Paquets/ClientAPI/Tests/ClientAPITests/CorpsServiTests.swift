// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
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
