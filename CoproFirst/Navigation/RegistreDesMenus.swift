// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Un écran natif qu'un menu du site ouvre : il se construit depuis son contexte.
///
/// Chaque fonctionnalité (`CoproFirst/Fonctions/<Menu>/`) rend son écran conforme,
/// dans son propre dossier, puis s'inscrit dans `RegistreDesMenus` en une ligne.
@MainActor
protocol EcranDeMenu: View {
    init(contexte: ContexteDeMenu)
}

/// Ce qu'un écran de menu reçoit : sa page (titre, pictogramme, libellé réglés par
/// l'administration), la résidence ouverte et la pile de navigation de son onglet.
struct ContexteDeMenu {
    let page: PageDeNavigation
    let installation: Installation
    let chemin: Binding<NavigationPath>
}

/// Le registre des menus : l'identifiant d'une page du site (`pages.ts`) → son écran.
///
/// ⚠️ UNE LIGNE PAR MENU, séparée des autres par une ligne vide : quatre sessions
/// parallèles y ajoutent chacune la leur sans conflit de fusion. Une page absente
/// d'ici s'affiche « Bientôt ». `scripts/verifier-parite.py` lit ces lignes : une
/// page dite « fait » dans `Parite/PARITE.md` doit y être, et rien n'y entre que le
/// site réserve à lui-même. Format lu : `"<id>": <Vue>.self,`.
@MainActor
enum RegistreDesMenus {
    static let ecrans: [String: any EcranDeMenu.Type] = [
        "tableau-de-bord": FilView.self,

        "mes-demandes": AffairesView.self,

        "residence": ResidenceView.self,
        "annuaire": AnnuaireView.self,

        "mon-lot": AccesView.self,
        "prestataires": PrestatairesView.self,

        "communaute": CommunauteView.self,

        "faq": FAQView.self,

        "profil": ProfilView.self,

        "notifications": NotificationsView.self,

        "espace-cs": EspaceCSView.self,

        // #15 — "delegations"

        // #16 — "admin"
    ]

    /// L'écran natif de la page, ou « Bientôt » tant qu'aucun n'est inscrit.
    static func ecran(_ contexte: ContexteDeMenu) -> AnyView {
        guard let type = ecrans[contexte.page.id] else {
            return AnyView(Bientot(page: contexte.page, installation: contexte.installation))
        }
        return AnyView(type.init(contexte: contexte))
    }
}

/// Une page du site que l'app ne porte pas encore : elle le dit, sans écran vide.
struct Bientot: View {
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
        .titreDeMenu()
        .toolbar { PastilleOuSuisJe(installation: installation, cloche: true) }
    }
}
