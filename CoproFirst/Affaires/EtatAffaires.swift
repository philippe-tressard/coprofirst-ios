// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Observation
import SwiftUI

/// La liste des affaires d'une résidence : chargement, contenu, ou une phrase.
@MainActor @Observable
final class EtatAffaires {
    enum Phase: Equatable {
        case chargement
        case pret
        case erreur(ErreurService)
    }

    private(set) var phase = Phase.chargement
    private(set) var affaires: [Affaire] = []
    var filtre = FiltreAffaires.toutes
    var recherche = ""

    var retenues: [Affaire] { affaires.retenues(par: filtre, recherche: recherche) }

    func charger(_ installation: Installation, avec service: any ServiceCoproFirst) async {
        if affaires.isEmpty { phase = .chargement }
        do {
            let lues = try await service.affaires(installation)
            withAnimation(.snappy) {
                affaires = lues
                phase = .pret
            }
        } catch {
            withAnimation(.snappy) { phase = .erreur(ErreurService.depuis(error)) }
        }
    }

    func archiver(_ affaire: Affaire, dans installation: Installation, avec service: any ServiceCoproFirst) async {
        let avant = affaires
        withAnimation(.snappy) { affaires.removeAll { $0.id == affaire.id } }
        do {
            try await service.archiver(affaire, dans: installation)
        } catch {
            withAnimation(.snappy) { affaires = avant }
        }
    }
}
