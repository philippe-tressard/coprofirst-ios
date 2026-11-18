// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// L'entrée dans une installation : GET /config dit si l'adresse mène à une résidence.
/// La seule chose que l'iPhone (`ServiceCoproFirst`) et l'Apple TV (`DecouverteAPI`)
/// demandent tous deux avant d'entrer — `EtatDecouverte` ne connaît qu'elle.
protocol DecouvreInstallation: Sendable {
    /// GET /config : l'adresse mène-t-elle à une résidence ? Son nom, son logo.
    func decouvrir(_ adresse: URL) async throws -> Installation
}

/// GET /config, lu une fois pour les deux apps : la réponse devient une `Installation`,
/// ou l'erreur de l'entrée.
enum Decouverte {
    static func lire(_ adresse: URL, client: Client) async throws -> Installation {
        // L'entrée : ici, et ici seulement, une réponse illisible veut dire « pas CoproFirst ».
        let sortie: Operations.GetConfig.Output
        do {
            sortie = try await client.getConfig()
        } catch {
            throw ErreurService.depuisEntree(ClientCoproFirst.cause(error))
        }
        switch sortie {
        case .ok(let ok):
            let cles = try ok.body.json.additionalProperties
            guard let installation = Installation(adresse: adresse, config: cles) else {
                throw ErreurService.pasCoproFirst
            }
            return installation
        case .undocumented(let statut, _):
            throw ErreurService.depuis(statut: statut)
        }
    }
}
