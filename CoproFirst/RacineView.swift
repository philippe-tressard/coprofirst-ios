// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La racine : la pile d'entrée (présentation, résidence, connexion), puis l'espace
/// de la résidence ouverte.
struct RacineView: View {
    @Environment(Parcours.self) private var parcours
    @Namespace private var zoom

    var body: some View {
        @Bindable var parcours = parcours
        Group {
            if let ouverte = parcours.ouverte {
                OngletsView(installation: ouverte)
                    .transition(.opacity)
            } else {
                NavigationStack(path: $parcours.chemin) {
                    PresentationView()
                        .navigationDestination(for: Parcours.Etape.self) { etape in
                            switch etape {
                            case .residence: ResidenceView()
                            case .connexion(let installation): ConnexionView(installation: installation)
                            }
                        }
                }
                .tint(Charte.primary)
                .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.35), value: parcours.ouverte)
        .environment(\.espaceZoom, zoom)
    }
}
