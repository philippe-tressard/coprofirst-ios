// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Une réponse simulée d'une route que le contrat ne TYPE pas (pas de `response_model`
/// côté serveur) : déclarée par sa route, faute de schéma.
///
/// `scripts/verifier-fixtures.py` vérifie que la route existe et qu'elle n'est toujours
/// pas typée ; le jour où le contrat la type, il échoue — la réponse se déclare alors par
/// son schéma (`FixturesAcces.Reponse`) et l'écran la lit par son type généré. Le JSON
/// se lit par `Relecture.lire(_:json:)`, comme le service réel lit la valeur du client.
///
/// Au contrat 1.26.0, plus aucune route lue par l'app n'est sans type (les quatre du
/// Paramétrage le sont depuis 1.16.0, #87) : le type reste, avec le juge, pour la
/// prochaine route que le serveur servirait sans `response_model`.
struct ReponseNonTypee: Sendable {
    let nom: String
    /// « GET /telemetry/dashboard » : la méthode et le chemin du contrat.
    let route: String
    let json: String

    func lire<T: Decodable>(_ type: T.Type) throws -> T {
        try Relecture.lire(type, json: Data(json.utf8))
    }
}
