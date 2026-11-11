// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'espace de la résidence ouverte : la barre du bas suit l'ORDRE RÉGLÉ PAR
/// L'ADMINISTRATION (`pages_order`) ; au-delà de quatre entrées, « Plus ». Une page
/// réservée à un rôle n'y paraît qu'à qui l'a (`PagesOuvertes`, profil de GET /auth/me).
struct OngletsView: View {
    let installation: Installation
    @Environment(\.palette) private var palette
    @Environment(Parcours.self) private var parcours

    /// Les onglets qui tiennent dans la barre ; au-delà, « Plus » (`Aiguillage.idPlus`).
    static let visibles = 4

    var body: some View {
        let pages = parcours.pagesDeLaBarre(installation)
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
                    .tag(Aiguillage.idPlus)
            }
        }
        .tint(palette.primary)
        // L'affaire d'un lien ou d'une notification, quand son onglet n'est pas dans la barre.
        .sheet(item: $parcours.porte.affaireEnFeuille) { affaire in
            NavigationStack {
                DetailAffaireView(id: affaire.id, installation: installation)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fermer") { parcours.porte.affaireEnFeuille = nil }
                                .accessibilityIdentifier("porte.fermer")
                        }
                    }
            }
            .presentationDragIndicator(.visible)
        }
        .feuilleNotifications(installation, ouverte: $parcours.clocheOuverte)
        // La barre dépend des rôles : ils se relisent à l'ouverture de la résidence.
        .task { await parcours.rafraichirProfil() }
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
                        EntreeDePlus(libelle: page.libelle, symbole: Pictogrammes.symbole(page.icone))
                    }
                    .accessibilityIdentifier("plus.\(page.id)")
                    .listRowBackground(palette.surface)
                }
                // Le profil n'a pas d'entrée de menu sur le site (pages.ts : href null) :
                // il vit ici, avec la déconnexion.
                NavigationLink {
                    ProfilView()
                } label: {
                    EntreeDePlus(libelle: "Profil", symbole: "person.crop.circle")
                }
                .accessibilityIdentifier("plus.profil")
                .listRowBackground(palette.surface)
                // Le pied de page du site : ©, mentions légales, confidentialité, logiciel libre.
                NavigationLink {
                    AProposView(installation: installation)
                } label: {
                    EntreeDePlus(libelle: "À propos", symbole: "info.circle")
                }
                .accessibilityIdentifier("plus.a-propos")
                .listRowBackground(palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            .navigationTitle("Plus")
            .titreDeMenu()
            .toolbar { PastilleOuSuisJe(installation: installation, cloche: true) }
        }
    }
}

/// Une entrée de « Plus » : pictogramme et libellé côte à côte. Aux tailles
/// d'accessibilité, le pictogramme passe au-dessus et laisse toute la largeur au
/// libellé, qui la prend sans couper un mot (`TexteSansCoupure`, #33).
private struct EntreeDePlus: View {
    let libelle: String
    let symbole: String
    @Environment(\.dynamicTypeSize) private var taille
    @Environment(\.palette) private var palette

    var body: some View {
        Group {
            if taille.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: symbole).accessibilityHidden(true)
                    TexteSansCoupure(texte: libelle)
                }
                .accessibilityElement(children: .combine)
            } else {
                Label(libelle, systemImage: symbole)
            }
        }
        .foregroundStyle(palette.text)
    }
}
