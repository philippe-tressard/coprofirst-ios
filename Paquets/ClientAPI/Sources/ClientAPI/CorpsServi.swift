// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Le corps JSON qu'une route a servi, gardé à la demande — pour y relire un champ que
/// le contrat du PLANCHER ne connaît pas encore (#89).
///
/// Le client généré décode une réponse typée par son schéma et ignore les clés qu'il ne
/// déclare pas : un champ servi par une installation plus récente que le plancher
/// (`gestes_roles`, contrat 1.18.0) disparaît avant que l'app le voie. L'appel se fait
/// donc toujours par le client généré, et `garder` en rend en plus le corps servi, que
/// l'app relit (`Relecture`) en tolérant l'absence du champ.
///
/// Rien n'est gardé hors d'un `garder` : les autres appels ne paient ni la copie ni la
/// mémoire. Le corps est lu jusqu'à `plafond` octets ; au-delà, l'appel échoue comme
/// une réponse illisible, jamais tronqué en silence.
public enum CorpsServi {
    /// Ce que l'intercepteur remplit pendant un `garder` — porté par la tâche, donc par
    /// le seul appel qui l'a demandé.
    @TaskLocal static var recueil: Recueil?

    /// La limite d'un corps gardé : la plus longue liste servie (les comptes d'une
    /// copropriété) tient en quelques centaines de kilo-octets.
    public static let plafond = 8 * 1024 * 1024

    /// L'appel, puis le corps JSON que sa réponse a servi (`nil` sans corps).
    public static func garder<T: Sendable>(
        _ appel: () async throws -> T
    ) async throws -> (sortie: T, corps: Data?) {
        let recueil = Recueil()
        let sortie = try await $recueil.withValue(recueil) { try await appel() }
        return (sortie, recueil.donnees)
    }

    final class Recueil: @unchecked Sendable {
        private let verrou = NSLock()
        private var lues: Data?

        var donnees: Data? { verrou.withLock { lues } }

        func poser(_ donnees: Data) { verrou.withLock { lues = donnees } }
    }
}

/// L'intercepteur du client (`ClientCoproFirst.client`) : sans `garder` en cours, il
/// passe la réponse telle quelle.
struct IntercepteurCorpsServi: ClientMiddleware {
    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let (reponse, corps) = try await next(request, body, baseURL)
        guard let recueil = CorpsServi.recueil, let corps else { return (reponse, corps) }
        let donnees = try await Data(collecting: corps, upTo: CorpsServi.plafond)
        recueil.poser(donnees)
        return (reponse, HTTPBody(donnees))
    }
}
