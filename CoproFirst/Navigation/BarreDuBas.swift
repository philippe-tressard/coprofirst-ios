// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La navigation en classe compacte (iPhone, iPad en Split View étroit) : la barre du bas
/// suit l'ORDRE RÉGLÉ PAR L'ADMINISTRATION (`pages_order`) ; au-delà de quatre entrées,
/// « Plus » — toujours là, puisqu'il porte le Profil et À propos : un compte qui n'a
/// qu'une page (le compte technique, #355) doit pouvoir se déconnecter.
struct BarreDuBas: View {
    let pages: [PageDeNavigation]
    let installation: Installation
    @Environment(Parcours.self) private var parcours

    var body: some View {
        @Bindable var parcours = parcours
        let visibles = PresentationNavigation.barreDuBas.visibles
        TabView(selection: $parcours.onglet) {
            ForEach(pages.prefix(visibles)) { page in
                EcranDePage(page: page, installation: installation)
                    .tabItem { Label(page.libelle, systemImage: Pictogrammes.symbole(page.icone)) }
                    .tag(page.id)
            }
            PlusView(
                pages: Array(pages.dropFirst(visibles)), installation: installation,
                ouverte: parcours.ouverteDansPlus)
                .tabItem { Label("Plus", systemImage: "ellipsis.circle") }
                .tag(Aiguillage.idPlus)
        }
    }
}

/// Les pages au-delà des quatre premières, puis Profil et À propos : leur écran s'ouvre
/// dans la pile de « Plus ». Celle qui y est ouverte se retient (`Parcours.ouverteDansPlus`),
/// et s'y rouvre en revenant de la barre latérale (`PresentationNavigation.traduire`).
private struct PlusView: View {
    let pages: [PageDeNavigation]
    let installation: Installation
    @Environment(\.palette) private var palette
    @Environment(Parcours.self) private var parcours
    @State private var chemin: NavigationPath
    /// L'entrée affichée en tête de la pile, pour distinguer un toucher dans la liste d'une
    /// page demandée d'ailleurs (la porte d'un lien, le retour de la barre latérale).
    @State private var affichee: String?

    init(pages: [PageDeNavigation], installation: Installation, ouverte: String?) {
        self.pages = pages
        self.installation = installation
        _chemin = State(initialValue: NavigationPath(ouverte.map { [EntreeDePlus(id: $0)] } ?? []))
    }

    var body: some View {
        NavigationStack(path: $chemin) {
            List {
                ForEach(pages) { page in
                    lien(EntreeDePlus(id: page.id), libelle: page.libelle, symbole: Pictogrammes.symbole(page.icone))
                }
                ForEach(EntreeFixe.allCases) { fixe in
                    lien(EntreeDePlus(id: fixe.rawValue), libelle: fixe.libelle, symbole: fixe.symbole)
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            .navigationTitle("Plus")
            .titreDeMenu()
            .toolbar { PastilleOuSuisJe(installation: installation, cloche: true) }
            .onAppear {
                affichee = nil
                parcours.ouverteDansPlus = nil
            }
            .navigationDestination(for: EntreeDePlus.self) { entree in
                ecran(entree).onAppear {
                    affichee = entree.id
                    parcours.ouverteDansPlus = entree.id
                }
            }
            .onChange(of: parcours.ouverteDansPlus) { _, demandee in
                if let demandee, demandee != affichee { chemin = NavigationPath([EntreeDePlus(id: demandee)]) }
            }
        }
    }

    private func lien(_ entree: EntreeDePlus, libelle: String, symbole: String) -> some View {
        NavigationLink(value: entree) {
            LigneDePlus(libelle: libelle, symbole: symbole)
        }
        .accessibilityIdentifier("plus.\(entree.id)")
        .listRowBackground(palette.surface)
    }

    @ViewBuilder
    private func ecran(_ entree: EntreeDePlus) -> some View {
        if let page = pages.first(where: { $0.id == entree.id }) {
            RegistreDesMenus.ecran(ContexteDeMenu(page: page, installation: installation, chemin: $chemin))
        } else if let fixe = EntreeFixe(rawValue: entree.id) {
            fixe.ecran(installation)
        }
    }
}

/// Une entrée de « Plus » poussée dans sa pile : une page, le profil ou « À propos ».
private struct EntreeDePlus: Hashable {
    let id: String
}

/// Une ligne de « Plus » : pictogramme et libellé côte à côte. Aux tailles
/// d'accessibilité, le pictogramme passe au-dessus et laisse toute la largeur au
/// libellé, qui la prend sans couper un mot (`TexteSansCoupure`, #33).
private struct LigneDePlus: View {
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
