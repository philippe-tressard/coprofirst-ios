// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// La mesure d'audience par le client GÉNÉRÉ : le lot est typé (`LotAudience`, au
/// plancher) ; son canal, au-dessus du plancher (contrat 1.31.0), s'ajoute au corps.
extension ServiceAPI: ServiceAudience {
    func envoyer(_ pages: [String], a installation: Installation) async throws {
        let lot = Components.Schemas.LotAudience(
            events: pages.map { .init(action: MesureAudience.action, page: $0) })
        let sortie = try await CorpsEnvoye.completer(avec: CanalAudience.app) {
            try await appeler { try await client(installation.adresse).postTelemetryCollect(body: .json(lot)) }
        }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.inattendue(statut)
        }
    }
}
