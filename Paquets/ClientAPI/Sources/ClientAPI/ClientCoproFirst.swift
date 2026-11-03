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

extension ClientCoproFirst {
    /// Un client sur une session URLSession donnée — une par installation, pour que
    /// les cookies de l'une ne partent jamais vers l'autre.
    public static func client(installation: URL, session: URLSession) -> Client {
        Client(
            serverURL: adresseAPI(installation: installation),
            configuration: Configuration(dateTranscoder: TranscodeurDates()),
            transport: URLSessionTransport(configuration: .init(session: session))
        )
    }

    /// La cause d'une erreur du client généré (réseau, décodage), sans son emballage.
    public static func cause(_ erreur: any Error) -> any Error {
        (erreur as? ClientError)?.underlyingError ?? erreur
    }

    /// Le FICHIER qu'une route a servi alors que le contrat annonçait du JSON : le
    /// client généré refuse le type, et son erreur porte la réponse. Rendu sur un 200
    /// seulement, jusqu'à `plafond` octets ; `nil` pour toute autre erreur.
    public static func fichierServi(_ erreur: any Error, plafond: Int = 50 * 1024 * 1024) async throws -> Data? {
        guard let erreur = erreur as? ClientError, erreur.response?.status == .ok,
            let corps = erreur.responseBody
        else { return nil }
        return try await Data(collecting: corps, upTo: plafond)
    }
}

/// Les dates de l'API : ISO 8601 avec ou sans fractions de seconde, et sans fuseau
/// lu comme UTC — FastAPI sérialise selon le type Python, pas toujours avec `Z`.
public struct TranscodeurDates: DateTranscoder {
    public init() {}

    public func encode(_ date: Date) throws -> String {
        date.formatted(.iso8601)
    }

    public func decode(_ texte: String) throws -> Date {
        let essais: [Date.ISO8601FormatStyle] = [
            .iso8601.year().month().day().dateTimeSeparator(.standard).time(includingFractionalSeconds: true)
                .timeZone(separator: .omitted),
            .iso8601,
        ]
        for style in essais {
            if let date = try? style.parse(texte) { return date }
        }
        // Sans fuseau : UTC.
        for style in essais {
            if let date = try? style.parse(texte + "Z") { return date }
        }
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Date illisible : \(texte)"))
    }
}
