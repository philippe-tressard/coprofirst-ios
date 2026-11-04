// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Une réponse que le contrat ne type pas (pas de `response_model` côté serveur),
/// relue en miroir dans le modèle de l'écran (#41) : les clés en `snake_case`
/// deviennent des propriétés en `camelCase`, et les dates se lisent comme le client
/// généré les lit (`TranscodeurDates` : ISO, sans fuseau = UTC).
///
/// Le seul endroit de l'app qui relit du JSON à la main : un modèle relu ici ne
/// déclare pas de `CodingKeys` en `snake_case` (la conversion les rendrait muets).
/// Chaque appel est un besoin noté pour coprofirst (#2460, #2505) : typer la réponse.
enum Relecture {
    /// Une valeur non typée du client généré (`OpenAPIValueContainer`, objet ou tableau).
    static func lire<T: Decodable>(_ type: T.Type, depuis valeur: some Encodable) throws -> T {
        try lire(type, json: JSONEncoder().encode(valeur))
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
}
