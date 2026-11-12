// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Le compte dans une résidence : qui l'on y est, et en sortir.
extension ServiceAPI {
    func profil(_ installation: Installation) async throws -> ProfilResidence {
        let sortie = try await appeler { try await client(installation.adresse).getAuthMe() }
        switch sortie {
        case .ok(let ok):
            return ProfilResidence(try ok.body.json)
        case .unprocessableContent:
            throw ErreurService.inattendue(422)
        case .undocumented(let statut, _):
            throw ErreurService.depuisLecture(statut)
        }
    }

    func deconnecter(_ installation: Installation) async -> Bool {
        var atteint = false
        do {
            let sortie = try await client(installation.adresse).postAuthLogout()
            if case .ok = sortie { atteint = true }
            // Un 401 dit une session déjà morte côté serveur : rien de plus à révoquer.
            if case .undocumented(let statut, _) = sortie, statut == 401 { atteint = true }
        } catch {
            atteint = false
        }
        // L'effacement local se fait TOUJOURS, serveur joint ou non : le jeton et la
        // lecture gardée pour la consultation hors ligne, par la même porte (#101).
        oublierCeQuiEstGarde(installation)
        sessions.oublier(installation.adresse)
        return atteint
    }
}

extension SessionsParHote {
    /// Oublie la session HTTP de cet hôte : ses cookies (en mémoire) partent avec elle.
    func oublier(_ adresse: URL) {
        let session = retirer(adresse)
        session?.configuration.httpCookieStorage?.removeCookies(since: .distantPast)
        session?.invalidateAndCancel()
    }
}
