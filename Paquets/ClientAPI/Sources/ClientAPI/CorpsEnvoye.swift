// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Des champs ENVOYÉS au-dessus du plancher — le pendant, à l'aller, de `CorpsServi` (#181).
///
/// Le type généré d'un corps (`TicketUpdate`) ne connaît que les champs du contrat du
/// PLANCHER : un champ qu'une installation plus récente accepte (`prestataire_ids`, contrat
/// 1.28.0) ne s'y écrit pas. L'appel se fait donc toujours par le client généré, et
/// `completer` ajoute à son corps JSON les champs donnés, le temps de CET appel seulement.
///
/// Un champ que le corps généré porte déjà n'est jamais remplacé : `Collision` — le jour
/// où le plancher le déclare, il s'écrit par le type généré et l'ajout se retire.
public enum CorpsEnvoye {
    /// L'objet JSON à ajouter, porté par la tâche : par le seul appel qui l'a demandé.
    @TaskLocal static var ajouts: Data?

    /// Un champ ajouté que le corps généré porte déjà.
    public struct Collision: Error, Equatable {
        public let champ: String
    }

    /// L'appel, avec `champs` ajoutés à son corps JSON — clés en `snake_case`
    /// (`prestataireIds` → `prestataire_ids`), comme le contrat.
    public static func completer<T: Sendable>(
        avec champs: some Encodable, _ appel: () async throws -> T
    ) async throws -> T {
        let encodeur = JSONEncoder()
        encodeur.keyEncodingStrategy = .convertToSnakeCase
        return try await $ajouts.withValue(try encodeur.encode(champs)) { try await appel() }
    }

    /// Le corps `envoye`, complété des `ajouts` : deux objets JSON réunis.
    static func reunir(_ envoye: Data, _ ajouts: Data) throws -> Data {
        guard var corps = try JSONSerialization.jsonObject(with: envoye) as? [String: Any],
            let champs = try JSONSerialization.jsonObject(with: ajouts) as? [String: Any]
        else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Corps non objet")) }
        for (champ, valeur) in champs {
            guard corps[champ] == nil else { throw Collision(champ: champ) }
            corps[champ] = valeur
        }
        return try JSONSerialization.data(withJSONObject: corps, options: .sortedKeys)
    }
}

/// L'intercepteur du client (`ClientCoproFirst.client`) : sans `completer` en cours, il
/// passe la requête telle quelle.
struct IntercepteurCorpsEnvoye: ClientMiddleware {
    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard let ajouts = CorpsEnvoye.ajouts, let body else { return try await next(request, body, baseURL) }
        let envoye = try await Data(collecting: body, upTo: CorpsServi.plafond)
        let reuni = try CorpsEnvoye.reunir(envoye, ajouts)
        var requete = request
        requete.headerFields[.contentLength] = String(reuni.count)
        return try await next(requete, HTTPBody(reuni), baseURL)
    }
}
