// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La racine : la pile d'entrée (accueil, en savoir plus, connexion, démo), puis
/// l'espace de la résidence ouverte. Elle pose la palette en vigueur pour tout l'écran.
struct RacineView: View {
    @Environment(Parcours.self) private var parcours

    var body: some View {
        @Bindable var parcours = parcours
        let palette = parcours.palette
        Group {
            if let ouverte = parcours.ouverte {
                OngletsView(installation: ouverte)
                    .transition(.opacity)
                    .sheet(isPresented: $parcours.proposerFaceID) {
                        FaceIDFeuille(installation: ouverte)
                            .presentationDetents([.medium, .large])
                            .presentationDragIndicator(.visible)
                    }
            } else {
                NavigationStack(path: $parcours.chemin) {
                    AccueilView()
                        .navigationDestination(for: Parcours.Etape.self) { etape in
                            switch etape {
                            case .enSavoirPlus: EnSavoirPlusView()
                            case .connexion(let preremplissage): ConnexionView(preremplissage: preremplissage)
                            case .demo: DemoView()
                            }
                        }
                }
                .tint(palette.primary)
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $parcours.changerDeResidence) {
            ChangerDeResidenceFeuille()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .environment(\.palette, palette)
        .animation(.smooth(duration: 0.35), value: parcours.ouverte)
        .animation(.smooth(duration: 0.4), value: palette.code)
        .onChange(of: palette.code, initial: true) { ApparenceNavigation.appliquer(palette) }
        .task { await rouvrirParFaceID() }
    }

    /// Retour suivant : la dernière résidence a gardé sa session sous Face ID → le fil,
    /// directement, sans repasser par l'accueil.
    private func rouvrirParFaceID() async {
        guard parcours.ouverte == nil, let derniere = parcours.connues.derniere,
            parcours.service.aUneSessionGardee(derniere)
        else { return }
        if (try? await parcours.service.reprendre(derniere)) != nil {
            parcours.ouvrir(derniere)
        }
    }
}
