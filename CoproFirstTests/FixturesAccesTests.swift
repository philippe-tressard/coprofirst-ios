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
/// (`FixturesAcces`), lu par les types générés. Ce test confronte chaque réponse au
/// schéma de sa route dans `openapi.json`, en descendant dans les objets imbriqués.

/// Chaque réponse simulée se lit par le type GÉNÉRÉ, comme une vraie réponse.
@Test func lesReponsesSimuleesSeLisentParLesTypesGeneres() throws {
    #expect(try FixturesAcces.lots().count == 3)
    #expect(try FixturesAcces.detenus(.vigik).map(\.type) == ["vigik", "vigik", "vigik"])
    #expect(try FixturesAcces.detenus(.telecommande).map(\.type) == ["telecommande"])
    #expect(try FixturesAcces.bauxLus().count == 3)
}

/// Aucun champ que le serveur ne sert, aucun champ requis qui manque — à tous les niveaux.
@Test(arguments: FixturesAcces.parSchema.map { ($0.nom, $0.schema) })
func uneReponseSimuleeALaFormeDuSchema(nom: String, schema: String) throws {
    let json = try #require(FixturesAcces.parSchema.first { $0.nom == nom }?.json)
    let reponse = try JSONSerialization.jsonObject(with: Data(json.utf8))
    let schemas = try SchemasDuContrat.lire()
    let elements = try #require(reponse as? [Any], "\(nom) : une liste est attendue")
    var ecarts: [String] = []
    for (rang, element) in elements.enumerated() {
        ecarts += schemas.ecarts(element, schema: schema, chemin: "\(nom)[\(rang)]")
    }
    #expect(ecarts.isEmpty, "\(ecarts.joined(separator: "\n"))")
}

/// Le contrôle lui-même sait échouer : un champ de trop est vu, un champ requis manquant aussi.
@Test func leControleDeFormeVoitUnChampDeTropEtUnManque() throws {
    let schemas = try SchemasDuContrat.lire()
    let avecType: [String: Any] = [
        "id": 1, "code": "X", "statut": "actif", "chez_locataire": false, "cree_le": "2025-01-01T00:00:00",
        "type": "vigik",
    ]
    #expect(schemas.ecarts(avecType, schema: "AccesPorteur", chemin: "x") == ["x.type : non servi par le serveur"])
    let sansCode: [String: Any] = ["id": 1, "statut": "actif", "chez_locataire": false, "cree_le": "2025-01-01"]
    #expect(schemas.ecarts(sansCode, schema: "AccesPorteur", chemin: "x") == ["x.code : requis, absent"])
    var statutInconnu = avecType
    statutInconnu["type"] = nil
    statutInconnu["statut"] = "volé"
    let ecarts = schemas.ecarts(statutInconnu, schema: "AccesPorteur", chemin: "x")
    #expect(ecarts == ["x.statut : « volé » hors de StatutAcces"])
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

/// Les schémas de `Paquets/ClientAPI/Sources/ClientAPI/openapi.json` (le contrat
/// généré), lus depuis le dépôt.
struct SchemasDuContrat {
    let schemas: [String: [String: Any]]

    static func lire() throws -> SchemasDuContrat {
        let racine = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let fichier = racine.appending(path: "Paquets/ClientAPI/Sources/ClientAPI/openapi.json")
        let contrat = try JSONSerialization.jsonObject(with: Data(contentsOf: fichier)) as? [String: Any]
        let composants = contrat?["components"] as? [String: Any]
        return SchemasDuContrat(schemas: composants?["schemas"] as? [String: [String: Any]] ?? [:])
    }

    /// Les écarts d'un objet JSON au schéma nommé, en descendant dans les `$ref`.
    func ecarts(_ valeur: Any, schema nom: String, chemin: String) -> [String] {
        guard let schema = schemas[nom] else { return ["\(chemin) : schéma \(nom) absent du contrat"] }
        // Une énumération (`StatutAcces`…) : la valeur doit en être.
        if let valeurs = schema["enum"] as? [String] {
            return valeurs.contains(valeur as? String ?? "") ? [] : ["\(chemin) : « \(valeur) » hors de \(nom)"]
        }
        guard let objet = valeur as? [String: Any] else { return ["\(chemin) : un objet est attendu"] }
        let proprietes = schema["properties"] as? [String: Any] ?? [:]
        let requis = schema["required"] as? [String] ?? []
        var ecarts: [String] = []
        for cle in objet.keys.sorted() where proprietes[cle] == nil {
            ecarts.append("\(chemin).\(cle) : non servi par le serveur")
        }
        for cle in requis.sorted() where objet[cle] == nil {
            ecarts.append("\(chemin).\(cle) : requis, absent")
        }
        for (cle, sous) in objet {
            guard let propriete = proprietes[cle] as? [String: Any] else { continue }
            ecarts += imbriques(sous, propriete: propriete, chemin: "\(chemin).\(cle)")
        }
        return ecarts
    }

    private func imbriques(_ valeur: Any, propriete: [String: Any], chemin: String) -> [String] {
        if let ref = propriete["$ref"] as? String {
            return ecarts(valeur, schema: String(ref.split(separator: "/").last ?? ""), chemin: chemin)
        }
        if let items = propriete["items"] as? [String: Any], let ref = items["$ref"] as? String,
            let liste = valeur as? [Any]
        {
            let nom = String(ref.split(separator: "/").last ?? "")
            return liste.enumerated().flatMap { ecarts($1, schema: nom, chemin: "\(chemin)[\($0)]") }
        }
        return []
    }
}
