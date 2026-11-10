// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que sert un hôte pour se dire installation de CoproFirst (#82).
enum PreuveHote: Equatable, Sendable {
    /// Son `apple-app-site-association` déclare l'app.
    case declaree
    /// Pas de fichier lisible : absent, redirigé, illisible, ou hôte injoignable.
    case absente
    /// Un fichier, mais qui ne déclare pas l'app.
    case sansLApp

    var reconnue: Bool { self == .declaree }
}

/// La preuve servie par une installation : `/.well-known/apple-app-site-association`,
/// que chaque installation sert depuis coprofirst#2459, doit déclarer l'app.
///
/// Ce fichier n'est PAS une route de l'API (il n'est pas dans le contrat, ni sous
/// `/api`) : il se lit ici, et ici seulement, par une session éphémère sans cookies ni
/// cache, qui refuse toute redirection — comme Apple le lit.
enum PreuveAASA {
    /// L'identifiant de l'app, tel que le fichier le déclare : équipe `GUX8KASNTG`
    /// (`DEVELOPMENT_TEAM` de `project.yml`) et `fr.coprofirst.app`, figé.
    static let identifiantApp = "GUX8KASNTG.fr.coprofirst.app"
    /// La taille au-delà de laquelle Apple ignore le fichier.
    static let plafond = 128 * 1024

    static func adresse(de installation: URL) -> URL {
        installation.appending(path: ".well-known/apple-app-site-association")
    }

    /// Lit la preuve de l'installation — `.absente` sur toute erreur de transport.
    static func lire(_ installation: URL) async -> PreuveHote {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration, delegate: SansRedirection(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        var requete = URLRequest(url: adresse(de: installation))
        requete.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (donnees, reponse) = try? await session.data(for: requete), let http = reponse as? HTTPURLResponse
        else { return .absente }
        return juger(statut: http.statusCode, donnees: donnees)
    }

    /// La réponse jugée : un 200, un JSON de moins de 128 Kio, qui déclare l'app dans
    /// `applinks.details` (`appIDs`, ou l'ancien `appID`) ou `webcredentials.apps`.
    static func juger(statut: Int, donnees: Data) -> PreuveHote {
        guard statut == 200, donnees.count <= plafond,
            let racine = try? JSONSerialization.jsonObject(with: donnees) as? [String: Any]
        else { return .absente }
        var declares: [String] = []
        let details = (racine["applinks"] as? [String: Any])?["details"] as? [[String: Any]] ?? []
        for detail in details {
            declares += detail["appIDs"] as? [String] ?? []
            if let ancien = detail["appID"] as? String { declares.append(ancien) }
        }
        declares += (racine["webcredentials"] as? [String: Any])?["apps"] as? [String] ?? []
        return declares.contains(identifiantApp) ? .declaree : .sansLApp
    }
}

/// Aucune redirection suivie : la preuve se lit à l'adresse même de l'hôte.
private final class SansRedirection: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

extension ServiceAPI {
    func preuve(_ adresse: URL) async -> PreuveHote {
        await PreuveAASA.lire(adresse)
    }
}
