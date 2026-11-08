// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Les deux écrans de la vitrine, mis en pages depuis `contenu.json` : « En savoir plus »
/// et la démo. Un contenu auquel manque un `id` requis (`ContenuVitrine.idsRequis`), un
/// titre ou un texte attendu ne donne PAS de pages : l'app garde alors sa lecture
/// précédente, jamais un écran à moitié vide.
struct PagesVitrine: Equatable, Sendable {
    let enSavoirPlus: PageEnSavoirPlus
    let demo: PageDemo

    /// Les pages d'un `contenu.json`, ou rien s'il est illisible, d'un format inconnu ou
    /// incomplet pour l'app.
    static func lire(_ donnees: Data) -> PagesVitrine? {
        guard let contenu = try? ContenuDuSite.lire(donnees) else { return nil }
        return PagesVitrine(contenu)
    }

    init?(_ contenu: ContenuDuSite) {
        typealias Vitrine = ContenuVitrine
        guard let heros = contenu.section(Vitrine.heros), let titre = heros.titre, let chapeau = heros.textes.first,
            let fonctions = contenu.section(Vitrine.fonctions), let section = fonctions.titre,
            let sousTitre = fonctions.textes.first,
            let demo = contenu.section(Vitrine.demo), let titreDemo = demo.titre, demo.textes.count >= 2
        else { return nil }
        var rangees: [PageEnSavoirPlus.Rangee] = []
        for accroche in Vitrine.rangees {
            guard let element = fonctions.element(accroche.id), let titre = element.titre,
                let ligne = element.textes.first
            else { return nil }
            rangees.append(.init(id: accroche.id, symbole: accroche.symbole, titre: titre, ligne: ligne))
        }
        var personnages: [PageDemo.Personnage] = []
        for role in Vitrine.roles {
            guard let element = demo.element(role.id), let nom = element.titre, let ligne = element.textes.first
            else { return nil }
            personnages.append(.init(code: role.code, role: nom, ligne: ligne, symbole: role.symbole))
        }
        enSavoirPlus = PageEnSavoirPlus(
            titre: titre, chapeau: premierePhrase(chapeau), section: section, sousTitre: sousTitre, rangees: rangees)
        self.demo = PageDemo(
            titre: titreDemo, chapeau: demo.textes[0], avertissement: demo.textes[1], personnages: personnages)
    }
}

/// « En savoir plus », mis en pages par `PagesVitrine`.
struct PageEnSavoirPlus: Equatable, Sendable {
    struct Rangee: Identifiable, Equatable, Sendable {
        let id: String
        let symbole: String
        let titre: String
        let ligne: String
    }

    /// `heros` : son titre, la première phrase de son premier texte.
    let titre: String
    let chapeau: String
    /// `fonctions` : son titre, son premier texte, puis les rangées de l'app.
    let section: String
    let sousTitre: String
    let rangees: [Rangee]
}

/// L'écran de la démo, mis en pages par `PagesVitrine`.
struct PageDemo: Equatable, Sendable {
    struct Personnage: Identifiable, Equatable, Sendable {
        let code: String
        let role: String
        let ligne: String
        let symbole: String
        var id: String { code }
    }

    /// `demo` : son titre, son premier texte (le chapeau), son deuxième (l'avertissement).
    let titre: String
    let chapeau: String
    let avertissement: String
    let personnages: [Personnage]
}
