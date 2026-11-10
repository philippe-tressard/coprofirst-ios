// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Observation
import SwiftUI

/// La vérification d'une adresse (GET /config) : en cours, réussie, ou une phrase —
/// celle d'une résidence sous le plancher comprise, pour les deux services (#83).
@MainActor @Observable
final class EtatDecouverte {
    private(set) var enCours = false
    private(set) var erreur: ErreurService?

    func decouvrir(_ adresse: URL, avec service: any ServiceCoproFirst) async -> Installation? {
        enCours = true
        erreur = nil
        defer { enCours = false }
        do {
            let installation = try await service.decouvrir(adresse)
            try installation.exigerLePlancher()
            return installation
        } catch {
            withAnimation(.snappy) { self.erreur = ErreurService.depuis(error) }
            return nil
        }
    }

    func signaler(_ erreur: ErreurService?) {
        withAnimation(.snappy) { self.erreur = erreur }
    }
}
