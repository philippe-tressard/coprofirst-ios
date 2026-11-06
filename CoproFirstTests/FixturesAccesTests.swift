// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// Le garde-fou du bogue du 05/11/2026 (#13) : l'onglet « Mes badges » affichait
/// « Cette adresse ne mène pas à une résidence CoproFirst » sur l'iPhone. L'app
/// exigeait un champ `type` que `/acces/mes-vigiks` ne sert pas, et l'API simulée,
/// elle, le fournissait. Les tests étaient donc verts.
///
/// Désormais, l'API simulée d'Accès sert du JSON à la forme EXACTE des routes
/// (`FixturesAcces`), lu par les types générés. Sa confrontation au schéma du serveur
/// (champ non servi, requis absent, énumération, type, à tous les niveaux) est faite
/// par UN juge, `scripts/verifier-fixtures.py` : `verifier-depot.sh` le rejoue contre le
/// contrat du dépôt, la concordance quotidienne (#20) contre la dernière version publiée.

/// Chaque réponse simulée se lit par le type GÉNÉRÉ, comme une vraie réponse.
@Test func lesReponsesSimuleesSeLisentParLesTypesGeneres() throws {
    #expect(try FixturesAcces.lots().count == 3)
    #expect(try FixturesAcces.detenus(.vigik).map(\.type) == ["vigik", "vigik", "vigik"])
    #expect(try FixturesAcces.detenus(.telecommande).map(\.type) == ["telecommande"])
    #expect(try FixturesAcces.bauxLus().count == 3)
}

// MARK: - Erreurs : « pas CoproFirst » est réservé à l'entrée

/// Une réponse REÇUE mais illisible dans une résidence ouverte : « inattendue »,
/// jamais « Cette adresse ne mène pas à une résidence CoproFirst ».
@Test func uneReponseIllisibleNEstPasPasCoproFirst() {
    // Ce que le client généré lève quand une réponse n'a pas un champ qu'il exige.
    let erreur = DecodingError.keyNotFound(AnyCodingKey("type"), .init(codingPath: [], debugDescription: "absent"))
    #expect(ErreurService.depuis(erreur) == .inattendue(0))
    #expect(ErreurService.depuis(erreur).phrase != ErreurService.pasCoproFirst.phrase)
}

/// À l'ENTRÉE (GET /config d'une adresse saisie), la même erreur dit « pas CoproFirst ».
@Test func aLEntreeUneReponseIllisibleDitPasCoproFirst() {
    let erreur = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "HTML"))
    #expect(ErreurService.depuisEntree(erreur) == .pasCoproFirst)
    #expect(ErreurService.depuisEntree(URLError(.notConnectedToInternet)) == .horsLigne)
    #expect(ErreurService.depuisEntree(URLError(.cannotFindHost)) == .injoignable)
    #expect(ErreurService.depuisEntree(ErreurService.hoteInconnu) == .hoteInconnu)
}

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ texte: String) { stringValue = texte }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
