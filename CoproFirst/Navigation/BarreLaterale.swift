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
struct BarreLaterale: View {
    let pages: [PageDeNavigation]
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var colonnes = NavigationSplitViewVisibility.all

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
            detail
        }
        .navigationSplitViewStyle(.balanced)
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

    /// La page retenue, chacune avec SA pile : changer de page repart de son écran. Un
    /// onglet qui n'est plus offert (un rôle retiré, « Plus » d'avant une rotation) : la
    /// première page, le fil.
    @ViewBuilder
    private var detail: some View {
        if let fixe = EntreeFixe(rawValue: parcours.onglet) {
            NavigationStack {
                fixe.ecran(installation)
                    .toolbar { PastilleOuSuisJe(installation: installation, cloche: true) }
            }
            .id(fixe.id)
        } else if let page = pages.first(where: { $0.id == parcours.onglet }) ?? pages.first {
            // La page, et la colonne où ses listes ouvrent leurs fiches (`ListeEtFiche`, #222).
            PageEtColonneDeFiche { EcranDePage(page: page, installation: installation) }
                .id(page.id)
        }
    }
}
