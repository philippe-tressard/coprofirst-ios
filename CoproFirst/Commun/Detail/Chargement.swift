// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Charger, puis montrer — jamais un écran blanc : le squelette pendant le
/// chargement, une phrase et « Réessayer » sur une erreur, le contenu ensuite.
struct Chargement<Valeur: Sendable, Contenu: View, Squelette: View>: View {
    let charger: @Sendable () async throws -> Valeur
    @ViewBuilder let contenu: (Valeur, _ recharger: @escaping () -> Void) -> Contenu
    @ViewBuilder let squelette: () -> Squelette
    @State private var etat = Etat.chargement
    @State private var essai = 0

    private enum Etat {
        case chargement
        case pret(Valeur)
        case erreur(ErreurService)
    }

    var body: some View {
        Group {
            switch etat {
            case .chargement:
                squelette()
                    .redacted(reason: .placeholder)
                    .allowsHitTesting(false)
                    .accessibilityLabel("Chargement")
            case .pret(let valeur):
                contenu(valeur) { essai += 1 }
                    .transition(.opacity)
            case .erreur(let erreur):
                MessageErreur(texte: erreur.phrase) {
                    etat = .chargement
                    essai += 1
                }
                .padding(Mise.marge)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .animation(.smooth(duration: 0.25), value: estPret)
        .task(id: essai) {
            do {
                let valeur = try await charger()
                etat = .pret(valeur)
            } catch {
                etat = .erreur(ErreurService.depuis(error))
            }
        }
    }

    private var estPret: Bool {
        if case .pret = etat { return true }
        return false
    }
}
