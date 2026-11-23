// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// La découverte de l'Apple TV : le client GÉNÉRÉ, lu par `Decouverte` comme sur l'iPhone,
/// sur une session éphémère — avant son appairage, l'écran de hall n'a ni compte ni cookie.
struct DecouverteAPI: DecouvreInstallation {
    func decouvrir(_ adresse: URL) async throws -> Installation {
        let session = URLSession(configuration: .ephemeral)
        let client = ClientCoproFirst.client(installation: adresse, session: session)
        return try await Decouverte.lire(adresse, client: client)
    }
}
