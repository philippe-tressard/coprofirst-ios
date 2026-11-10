// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les logos de résidence déjà lus, gardés en mémoire le temps du lancement (#70).
///
/// La clé est l'ADRESSE (`Installation.adresseLogo(sombre:)`) : le logo et sa variante
/// sombre n'ont pas la même, si bien qu'ils se gardent côte à côte — passer d'un thème
/// à l'autre puis revenir ne relit rien. Une même adresse demandée deux fois pendant
/// sa lecture ne part qu'une fois ; un échec ne se garde pas, la prochaine apparition
/// réessaie.
@MainActor
@Observable
final class LogosEnMemoire {
    /// Celui de l'app : la pastille, la feuille et la connexion le partagent.
    static let commun = LogosEnMemoire()

    private var images: [URL: UIImage] = [:]
    @ObservationIgnored private var enCours: [URL: Task<UIImage?, Never>] = [:]

    /// L'image déjà lue à cette adresse, sans rien demander.
    func image(_ adresse: URL) -> UIImage? {
        images[adresse]
    }

    /// L'image à cette adresse : de la mémoire, sinon lue par `lire` — `nil` si elle
    /// n'a pas pu l'être (réseau, réponse illisible).
    @discardableResult
    func charger(_ adresse: URL, lire: @escaping @Sendable (URL) async throws -> Data) async -> UIImage? {
        if let image = images[adresse] { return image }
        if let tache = enCours[adresse] { return await tache.value }
        let tache = Task { () -> UIImage? in
            guard let donnees = try? await lire(adresse) else { return nil }
            return UIImage(data: donnees)
        }
        enCours[adresse] = tache
        let image = await tache.value
        enCours[adresse] = nil
        if let image { images[adresse] = image }
        return image
    }
}
