// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// La mesure d'audience par le client GÉNÉRÉ : le lot est typé (`LotAudience`), canal et
/// appareil compris. `ios` range ses vues sous « App iPhone » ; une valeur hors de la liste
/// du serveur serait refusée (422) — elle ne s'écrit pas, elle se choisit dans l'énumération
/// générée (`.ios`, `AppareilAudience`).
extension ServiceAPI: ServiceAudience {
    func envoyer(_ pages: [String], appareil: AppareilAudience, a installation: Installation) async throws {
        let lot = Components.Schemas.LotAudience(
            appareil: appareil.rawValue, canal: .ios,
            events: pages.map { .init(action: MesureAudience.action, page: $0) })
        let sortie = try await appeler { try await client(installation.adresse).postTelemetryCollect(body: .json(lot)) }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.inattendue(statut)
        }
    }
}
