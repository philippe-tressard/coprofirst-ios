// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La racine : la pile d'entrée (l'accueil à la première ouverture, le retour à la
/// dernière résidence ensuite — `EntreeView`), puis l'espace de la résidence ouverte.
/// Elle pose la palette en vigueur pour tout l'écran.
struct RacineView: View {
    @Environment(Parcours.self) private var parcours

    var body: some View {
        @Bindable var parcours = parcours
        let palette = parcours.palette
        Group {
            if let ouverte = parcours.ouverte {
                OngletsView(installation: ouverte)
                    // Le réseau revenu, la session reprise : l'espace se reconstruit, tout se relit (#101).
                    .id(parcours.consultation == nil)
                    .repriseEnLigne()
                    .transition(.opacity)
                    .sheet(isPresented: $parcours.proposerFaceID) {
                        FaceIDFeuille(installation: ouverte)
                            .presentationDetents([.medium, .large])
                            .presentationDragIndicator(.visible)
                    }
            } else {
                NavigationStack(path: $parcours.chemin) {
                    EntreeView()
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
            FeuilleResidence()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        // Un lien universel (#18) : une seule porte, celle des notifications (#17).
        .onOpenURL { url in
            if let destination = LienUniversel.destination(url) { parcours.suivre(destination) }
        }
        .sheet(item: $parcours.porte.pageWeb) { page in
            PageWebView(url: page.url).ignoresSafeArea()
        }
        .environment(\.palette, palette)
        .themeChoisi()
        .animation(.smooth(duration: 0.35), value: parcours.ouverte)
        .animation(.smooth(duration: 0.4), value: palette.code)
        .onChange(of: palette.code, initial: true) { ApparenceNavigation.appliquer(palette) }
    }
}
