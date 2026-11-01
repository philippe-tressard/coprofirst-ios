// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

/// Point d'entrée unique vers l'API d'une installation de CoproFirst.
///
/// Les chemins du contrat s'entendent sous `/api` (PROVENANCE-OPENAPI.md) :
/// l'adresse de l'installation se complète ici, et nulle part ailleurs.
public enum ClientCoproFirst {
    /// L'adresse de base de l'API d'une installation : `https://<hôte>/api`.
    public static func adresseAPI(installation: URL) -> URL {
        installation.appending(path: "api", directoryHint: .isDirectory)
    }

    /// Un client généré, branché sur l'installation donnée.
    public static func client(
        installation: URL,
        transport: any ClientTransport = URLSessionTransport()
    ) -> Client {
        Client(serverURL: adresseAPI(installation: installation), transport: transport)
    }
}
