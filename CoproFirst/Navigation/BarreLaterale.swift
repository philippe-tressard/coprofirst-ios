// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La navigation en classe RÉGULIÈRE (iPad en plein écran, en paysage comme en portrait) :
/// une barre latérale qui liste TOUTES les pages, dans l'ordre réglé par l'administration,
/// puis Profil et À propos ; la page retenue occupe le détail, avec sa propre pile (#221).
///
/// `NavigationSplitView` à deux colonnes, pas la `TabView` `.sidebarAdaptable`, qui exige
/// iOS 18 : le minimum reste iOS 17 (décision du 15/11/2026). Les deux colonnes restent
/// visibles en portrait (`.all`, `.balanced`) : aucune page n'est derrière un geste ; le
/// bouton du système replie la barre pour qui veut toute la largeur.
///
/// En PORTRAIT, deux colonnes et pas trois : la barre et la page, dont la liste ouvre sa
/// fiche par-dessus elle, comme sur l'iPhone (`FicheParDessus`). Liste et fiche côte à côte n'y laissaient à chacune qu'un tiers d'écran,
/// illisible. En paysage, rien ne change : liste et fiche côte à côte (#222).
struct BarreLaterale: View {
    let pages: [PageDeNavigation]
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var colonnes = NavigationSplitViewVisibility.all
    /// La taille de la fenêtre : le portrait se lit sur elle, jamais sur l'appareil.
    @State private var fenetre = CGSize.zero

    var body: some View {
        NavigationSplitView(columnVisibility: $colonnes) {
            List(selection: selection) {
                Section {
                    ForEach(pages) { page in
                        ligne(page.id, libelle: page.libelle, symbole: Pictogrammes.symbole(page.icone))
                    }
                }
                Section {
                    ForEach(EntreeFixe.allCases) { fixe in
                        ligne(fixe.rawValue, libelle: fixe.libelle, symbole: fixe.symbole)
                    }
                }
            }
            .navigationTitle(installation.nom)
            .navigationBarTitleDisplayMode(.inline)
        } detail: {
            PageRetenue(pages: pages, installation: installation)
                .environment(\.ficheParDessus, FicheParDessus.enPortrait(fenetre))
        }
        .navigationSplitViewStyle(.balanced)
        .onGeometryChange(for: CGSize.self, of: FicheParDessus.fenetre) { fenetre = $0 }
    }

    /// La sélection de la liste, c'est l'onglet du parcours : la porte d'un lien et le
    /// logement du fil (`parcours.onglet = "mon-lot"`) la changent comme un toucher.
    private var selection: Binding<String?> {
        Binding(
            get: { parcours.onglet },
            set: { if let id = $0 { parcours.onglet = id } })
    }

    private func ligne(_ id: String, libelle: String, symbole: String) -> some View {
        Label(libelle, systemImage: symbole)
            .elementIdentifie("barre.\(id)", lu: libelle)
            .tag(id)
    }
}
