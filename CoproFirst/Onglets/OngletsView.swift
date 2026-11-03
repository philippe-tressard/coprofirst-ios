// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'espace de la résidence ouverte : la barre du bas suit l'ORDRE RÉGLÉ PAR
/// L'ADMINISTRATION (`pages_order`) ; au-delà de quatre entrées, « Plus ».
struct OngletsView: View {
    let installation: Installation
    @Environment(\.palette) private var palette
    @State private var selection = OrdrePages.idFil

    private static let visibles = 4

    var body: some View {
        let pages = installation.pages
        TabView(selection: $selection) {
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

/// L'écran natif d'une page du site ; celles qui ne sont pas encore livrées le disent.
private struct EcranDePage: View {
    let page: PageDeNavigation
    let installation: Installation
    @State private var chemin = NavigationPath()

    var body: some View {
        NavigationStack(path: $chemin) {
            switch page.id {
            case OrdrePages.idFil: FilView(installation: installation, chemin: $chemin)
            case "mes-demandes": AffairesView(installation: installation)
            default: Bientot(page: page, installation: installation)
            }
        }
    }
}

private struct PlusView: View {
    let pages: [PageDeNavigation]
    let installation: Installation
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            List(pages) { page in
                NavigationLink {
                    Bientot(page: page, installation: installation)
                } label: {
                    Label(page.libelle, systemImage: Pictogrammes.symbole(page.icone))
                        .foregroundStyle(palette.text)
                }
                .listRowBackground(palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            .navigationTitle("Plus")
            .toolbar { PastilleOuSuisJe(installation: installation, cloche: true) }
        }
    }
}

private struct Bientot: View {
    let page: PageDeNavigation
    let installation: Installation
    @Environment(\.palette) private var palette

    var body: some View {
        ContentUnavailableView(
            "Bientôt", systemImage: Pictogrammes.symbole(page.icone),
            description: Text("« \(page.titre) » arrive dans une prochaine version de l'app.")
        )
        .background(palette.bg)
        .navigationTitle(page.titre)
        .toolbar { PastilleOuSuisJe(installation: installation, cloche: true) }
    }
}
