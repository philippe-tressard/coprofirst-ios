// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'espace de la résidence ouverte : la barre du bas suit l'ORDRE RÉGLÉ PAR
/// L'ADMINISTRATION (`pages_order`) ; au-delà de quatre entrées, « Plus ».
struct OngletsView: View {
    let installation: Installation
    @Environment(\.palette) private var palette
    @Environment(Parcours.self) private var parcours

    private static let visibles = 4

    var body: some View {
        let pages = installation.pages
        @Bindable var parcours = parcours
        TabView(selection: $parcours.onglet) {
            ForEach(pages.prefix(Self.visibles)) { page in
                EcranDePage(page: page, installation: installation)
                    .tabItem { Label(page.libelle, systemImage: Pictogrammes.symbole(page.icone)) }
                    .tag(page.id)
            }
            if pages.count > Self.visibles {
                PlusView(pages: Array(pages.dropFirst(Self.visibles)), installation: installation)
                    .tabItem { Label("Plus", systemImage: "ellipsis.circle") }
                    .tag("plus")
            }
        }
        .tint(palette.primary)
    }
}

/// Un onglet de la barre : sa pile de navigation, et l'écran que le registre des
/// menus inscrit pour sa page (`RegistreDesMenus`) — « Bientôt » sinon.
private struct EcranDePage: View {
    let page: PageDeNavigation
    let installation: Installation
    @State private var chemin = NavigationPath()

    var body: some View {
        NavigationStack(path: $chemin) {
            RegistreDesMenus.ecran(ContexteDeMenu(page: page, installation: installation, chemin: $chemin))
        }
    }
}

/// Les pages au-delà des quatre premières : leur écran s'ouvre dans la pile de « Plus ».
private struct PlusView: View {
    let pages: [PageDeNavigation]
    let installation: Installation
    @Environment(\.palette) private var palette
    @State private var chemin = NavigationPath()

    var body: some View {
        NavigationStack(path: $chemin) {
            List {
                ForEach(pages) { page in
                    NavigationLink {
                        RegistreDesMenus.ecran(ContexteDeMenu(page: page, installation: installation, chemin: $chemin))
                    } label: {
                        Label(page.libelle, systemImage: Pictogrammes.symbole(page.icone))
                            .foregroundStyle(palette.text)
                    }
                    .listRowBackground(palette.surface)
                }
                // Le profil n'a pas d'entrée de menu sur le site (pages.ts : href null) :
                // il vit ici, avec la déconnexion.
                NavigationLink {
                    ProfilView()
                } label: {
                    Label("Profil", systemImage: "person.crop.circle").foregroundStyle(palette.text)
                }
                .accessibilityIdentifier("plus.profil")
                .listRowBackground(palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            .navigationTitle("Plus")
            .toolbar { PastilleOuSuisJe(installation: installation, cloche: true) }
        }
    }
}
