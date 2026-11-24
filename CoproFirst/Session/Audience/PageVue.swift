// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le chemin, sur le site, de l'écran que l'app montre (coprofirst#2726) : ce que le site
/// enregistre (`window.location.pathname`, et `<chemin>#<onglet>` pour un onglet,
/// `trackTabView`). Les pages des deux clients coïncident ainsi au tableau de bord.
///
/// Une page du menu se lit dans la table GÉNÉRÉE (`PagesParDefaut`), jamais écrite ici.
enum CheminDuSite {
    /// La route d'une page du menu (`pages.ts`) : `communaute` → `/sondages`.
    static func page(_ id: String) -> String? {
        PagesParDefaut.toutes.first { $0.id == id }?.route
    }

    /// Un onglet d'une page : `/admin#telemetry`, comme `trackTabView` du site.
    static func onglet(_ onglet: String, de route: String) -> String { "\(route)#\(onglet)" }

    /// La vue Affaires : `/tickets`, la route générée de sa page (`DroitsAffaires.page`) —
    /// jamais écrite à la main (#348).
    static var affaires: String? { page(DroitsAffaires.page) }

    /// Une affaire : `/tickets/123` (`routes/(app)/tickets/[id]` du site).
    static func affaire(_ id: Int) -> String? { affaires.map { "\($0)/\(id)" } }

    /// L'affaire que désigne un chemin du site (`/tickets/123`, `/tickets/123#msg-4`), `nil` sinon.
    static func affaire(chemin: String) -> Int? {
        guard let affaires, chemin.hasPrefix(affaires + "/") else { return nil }
        return Int(chemin.dropFirst(affaires.count + 1).prefix { $0.isNumber })
    }

    /// L'adresse de la page d'une affaire sur son installation — celle de `lien_ticket()`
    /// côté serveur : le lien qui se copie et se partage.
    static func adresse(affaire id: Int, sur installation: URL) -> URL? {
        affaire(id).map { installation.appending(path: String($0.dropFirst())) }
    }

    /// Un sondage : `/sondages/12` (`routes/(app)/sondages/[id]`), sous la route de la Communauté.
    static func sondage(_ id: Int) -> String? { page(OngletCommunaute.page).map { "\($0)/\(id)" } }

    /// Le profil n'a pas d'entrée de menu (`href: null` dans `pages.ts`), donc pas de
    /// route générée : celle du site, `routes/(app)/profil`.
    static let profil = "/profil"
}

extension View {
    /// Note l'écran comme une page vue du site — à son apparition, et à chaque changement
    /// de chemin (un autre onglet). `nil` : rien à noter.
    func pageVue(_ chemin: String?) -> some View { modifier(PageVue(chemin: chemin)) }
}

private struct PageVue: ViewModifier {
    let chemin: String?
    @Environment(Parcours.self) private var parcours

    func body(content: Content) -> some View {
        content
            .onAppear { if let chemin { parcours.audience.noter(chemin) } }
            .onChange(of: chemin) { _, neuf in
                if let neuf { parcours.audience.noter(neuf) }
            }
    }
}
