// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

extension AvisDuGeste {
    /// Un service que la session ne réalise pas (l'aperçu, une session sans API).
    static let indisponible = "Ce geste n'est pas disponible ici."

    /// Un geste qui s'annonce par l'avis, écrit une fois (le bandeau et l'Historique d'une
    /// affaire, le Règlement, le Profil — #286) : sans service, la phrase « pas
    /// disponible » ; sinon l'envoi, la phrase de réussite, puis `apres` (relire ce qui
    /// change) ; un échec dit la phrase du serveur.
    @discardableResult
    func agir<Service: Sendable>(
        avec service: Service?, reussite: String, apres: () -> Void = {},
        _ envoi: (Service) async throws -> Void
    ) async -> Bool {
        guard let service else {
            dire(Self.indisponible, ton: .error)
            return false
        }
        do {
            try await envoi(service)
            dire(reussite)
            apres()
            return true
        } catch {
            dire(ErreurService.depuis(error).phrase, ton: .error)
            return false
        }
    }

    /// Un geste d'une FILE à traiter (Espace CS › Comptes, Admin › À traiter), écrit une fois
    /// (#348) : réussite → l'annonce se dit et l'erreur de la page s'efface ; échec → la
    /// phrase du serveur va à la page (`echec`, au-dessus de la file), pas à l'avis.
    func traiter(_ echec: Binding<String?>, _ faire: @escaping () async throws -> PhraseAvis) {
        Task {
            do {
                let annonce = try await faire()
                withAnimation(.snappy) { echec.wrappedValue = nil }
                dire(annonce)
            } catch {
                withAnimation(.snappy) { echec.wrappedValue = ErreurService.depuis(error).phrase }
            }
        }
    }
}
