// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les logos de résidence déjà lus, gardés en mémoire le temps du lancement (#70).
///
/// La clé est la DEMANDE (`Installation.logo(sombre:)`) : le logo et sa variante
/// sombre n'ont pas la même, si bien qu'ils se gardent côte à côte — passer d'un thème
/// à l'autre puis revenir ne relit rien. Une même demande faite deux fois pendant
/// sa lecture ne part qu'une fois ; un échec ne se garde pas, la prochaine apparition
/// réessaie.
@MainActor
@Observable
final class LogosEnMemoire {
    /// Celui de l'app : la pastille, la feuille et la connexion le partagent.
    static let commun = LogosEnMemoire()

    private var images: [LogoDemande: UIImage] = [:]
    @ObservationIgnored private var enCours: [LogoDemande: Task<UIImage?, Never>] = [:]

    /// L'image déjà lue pour cette demande, sans rien lire.
    func image(_ demande: LogoDemande) -> UIImage? {
        images[demande]
    }

    /// L'image de cette demande : de la mémoire, sinon lue par `lire` — `nil` si elle
    /// n'a pas pu l'être (réseau, réponse illisible).
    @discardableResult
    func charger(_ demande: LogoDemande, lire: @escaping @Sendable (LogoDemande) async throws -> Data) async -> UIImage? {
        if let image = images[demande] { return image }
        if let tache = enCours[demande] { return await tache.value }
        let tache = Task { () -> UIImage? in
            guard let donnees = try? await lire(demande) else { return nil }
            return UIImage(data: donnees)
        }
        enCours[demande] = tache
        let image = await tache.value
        enCours[demande] = nil
        if let image { images[demande] = image }
        return image
    }
}
