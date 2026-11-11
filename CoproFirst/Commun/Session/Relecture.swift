// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import OpenAPIRuntime

/// Une réponse que le contrat ne type pas (pas de `response_model` côté serveur),
/// relue en miroir dans le modèle de l'écran (#41) : les clés en `snake_case`
/// deviennent des propriétés en `camelCase`, et les dates se lisent comme le client
/// généré les lit (`TranscodeurDates` : ISO, sans fuseau = UTC).
///
/// Le seul endroit de l'app qui relit du JSON à la main : un modèle relu ici ne
/// déclare pas de `CodingKeys` en `snake_case` (la conversion les rendrait muets).
/// Chaque appel est un besoin noté pour coprofirst (#2460, #2505) : typer la réponse.
enum Relecture {
    /// Une valeur NON TYPÉE du client généré (`OpenAPIValueContainer`, objet ou tableau).
    ///
    /// 🔴 Ce paramètre n'accepte rien d'autre, exprès (bogue du 06/11/2026) : le contrat
    /// 1.5.0 a typé `/idees` et `/annonces`, la Communauté relisait ces structures
    /// GÉNÉRÉES par ici — réencodées sans le transcodeur du client, leurs dates partaient
    /// en nombre, et « Impossible d'afficher les idées » s'affichait sur l'iPhone, l'API
    /// simulée ne passant pas par ce chemin. Une sortie typée ne compile plus ici : elle
    /// se lit par son type généré (`Idee(_:)`, `Annonce(_:)`…).
    static func lire<T: Decodable>(_ type: T.Type, depuis valeur: OpenAPIValueContainer) throws -> T {
        try lire(type, json: JSONEncoder().encode(valeur))
    }

    /// Des objets libres (un tableau d'objets à `additionalProperties` seules) — même
    /// garde : des conteneurs non typés, rien d'autre.
    static func lire<T: Decodable>(_ type: T.Type, depuis objets: [OpenAPIObjectContainer]) throws -> T {
        try lire(type, json: JSONEncoder().encode(objets))
    }

    /// Le même JSON, déjà en octets (une réponse servie hors contrat, un test).
    static func lire<T: Decodable>(_ type: T.Type, json donnees: Data) throws -> T {
        let decodeur = JSONDecoder()
        decodeur.keyDecodingStrategy = .convertFromSnakeCase
        decodeur.dateDecodingStrategy = .custom { lecteur in
            try TranscodeurDates().decode(lecteur.singleValueContainer().decode(String.self))
        }
        return try decodeur.decode(T.self, from: donnees)
    }

    /// Ce qu'une réponse TYPÉE sert au-dessus du plancher (#89) : des champs que le
    /// contrat du plancher ne déclare pas, que le type généré ignore, relus dans le corps
    /// servi (`CorpsServi.garder`). Le modèle relu n'a que des champs facultatifs.
    ///
    /// Une installation antérieure ne les sert pas : `nil`, et l'écran garde son geste
    /// d'avant. Un corps illisible vaut aussi `nil` — défaut FERMÉ : l'écran n'offre
    /// jamais un geste que le serveur n'a pas annoncé, et la lecture typée, elle, a déjà
    /// réussi.
    static func auDessusDuPlancher<T: Decodable>(_ type: T.Type, corps: Data?) -> T? {
        guard let corps else { return nil }
        return try? lire(type, json: corps)
    }

    /// La même relecture sur une LISTE typée, rangée par identifiant — l'écran retrouve
    /// chaque ligne du type généré par le sien.
    static func auDessusDuPlancher<T: Decodable & Identifiable>(
        parLigne type: T.Type, corps: Data?
    ) -> [T.ID: T] {
        let lus = auDessusDuPlancher([T].self, corps: corps) ?? []
        return Dictionary(lus.map { ($0.id, $0) }, uniquingKeysWith: { premier, _ in premier })
    }

    /// Un type GÉNÉRÉ, décodé comme le client généré le décode (clés du contrat, dates
    /// par `TranscodeurDates`) — l'API simulée sert ses réponses en JSON par ici, pour
    /// passer par le MÊME branchement que le service réel (`Fixtures*.swift`).
    static func generee<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        let decodeur = JSONDecoder()
        decodeur.dateDecodingStrategy = .custom { lecteur in
            try TranscodeurDates().decode(lecteur.singleValueContainer().decode(String.self))
        }
        return try decodeur.decode(T.self, from: Data(json.utf8))
    }
}
