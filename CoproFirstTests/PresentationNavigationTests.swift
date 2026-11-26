// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import Testing

@testable import CoproFirst

// La navigation en classe compacte ou régulière (#221) : la page ouverte survit au
// passage de l'une à l'autre — rotation, Split View, pliage.

private let pages = ["tableau-de-bord", "residence", "mes-demandes", "mon-lot", "annuaire", "faq", "communaute"]
private typealias Place = PresentationNavigation.Place

/// Une suite nommée : l'échantillon iPad de la CI la joue par son nom.
struct PresentationNavigationTests {
    @Test func laClasseDeTailleChoisitLaPresentationJamaisLAppareil() {
        #expect(PresentationNavigation.pour(.regular) == .barreLaterale)
        #expect(PresentationNavigation.pour(.compact) == .barreDuBas)
        #expect(PresentationNavigation.pour(nil) == .barreDuBas, "inconnue : la barre du bas, qui tient partout")
    }

    @Test func laBarreLateraleMontreToutesLesPages() {
        #expect(PresentationNavigation.barreDuBas.visibles == 4)
        let toutes = PagesParDefaut.toutes.map(\.id)
        for id in toutes {
            #expect(
                Aiguillage.aiguiller(.page(id), pages: toutes, visibles: PresentationNavigation.barreLaterale.visibles)
                    == .onglet(id), "\(id) : sa page, jamais « Plus »")
        }
        let auDela = ["faq", "annuaire", "residence", "mon-lot", "mes-demandes"]
        #expect(
            Aiguillage.aiguiller(
                .affaire(id: 41, message: nil), pages: auDela, visibles: PresentationNavigation.barreLaterale.visibles)
                == .affaireDansLOnglet(onglet: "mes-demandes", id: 41),
            "une affaire s'ouvre dans sa page, jamais en feuille")
    }

    @Test func versLaBarreLateraleLaPageOuverteResteOuverte() {
        let vers = { (place: Place) in PresentationNavigation.traduire(place, vers: .barreLaterale, pages: pages) }
        #expect(vers(Place(onglet: "residence")) == Place(onglet: "residence"))
        #expect(
            vers(Place(onglet: Aiguillage.idPlus, dansPlus: "faq")) == Place(onglet: "faq"), "ouverte dans « Plus »")
        #expect(vers(Place(onglet: Aiguillage.idPlus, dansPlus: "profil")) == Place(onglet: "profil"))
        #expect(vers(Place(onglet: Aiguillage.idPlus)) == Place(onglet: "annuaire"), "« Plus » seul : sa première page")
        #expect(
            PresentationNavigation.traduire(
                Place(onglet: Aiguillage.idPlus), vers: .barreLaterale, pages: ["tableau-de-bord"])
                == Place(onglet: EntreeFixe.profil.rawValue))
    }

    @Test func versLaBarreDuBasUnePageAuDelaSeRouvreDansPlus() {
        let vers = { (onglet: String) in
            PresentationNavigation.traduire(Place(onglet: onglet), vers: .barreDuBas, pages: pages)
        }
        #expect(vers("mon-lot") == Place(onglet: "mon-lot"), "dans les quatre : son onglet")
        #expect(vers("communaute") == Place(onglet: Aiguillage.idPlus, dansPlus: "communaute"))
        #expect(vers("a-propos") == Place(onglet: Aiguillage.idPlus, dansPlus: "a-propos"))
        #expect(vers("admin") == Place(onglet: Aiguillage.idPlus), "une page plus offerte : « Plus », sans page")
        #expect(
            PresentationNavigation.traduire(
                Place(onglet: "profil"), vers: .barreDuBas, pages: ["tableau-de-bord", "faq"])
                == Place(onglet: Aiguillage.idPlus, dansPlus: "profil"), "« Plus » toujours là (#355)")
    }

    @Test func unAllerRetourRendLaMemePage() {
        for onglet in pages + EntreeFixe.allCases.map(\.rawValue) {
            let bas = PresentationNavigation.traduire(Place(onglet: onglet), vers: .barreDuBas, pages: pages)
            let retour = PresentationNavigation.traduire(bas, vers: .barreLaterale, pages: pages)
            #expect(retour == Place(onglet: onglet), "\(onglet)")
        }
    }

    /// Les entrées fixes partagent l'espace des identifiants de page : une page du site du même
    /// nom rendrait la barre ambiguë.
    @Test func lesEntreesFixesNePortentPasLeNomDUnePage() {
        let ids = Set(PagesParDefaut.toutes.map(\.id))
        for fixe in EntreeFixe.allCases {
            #expect(!ids.contains(fixe.rawValue), "\(fixe.rawValue)")
        }
        #expect(!ids.contains(Aiguillage.idPlus))
    }

    /// « À propos » ferme la liste « Plus » : `GrandTexteUITests` la fait défiler JUSQU'À cette
    /// entrée, le seul signe lu de sa fin (un glisser perdu laisse aussi « rien de neuf », #390).
    /// Une entrée fixe ajoutée après elle échapperait au parcours en AX5 : ce test le dit.
    @Test func aProposFermeLaListePlus() {
        #expect(EntreeFixe.allCases.last == .aPropos)
    }
}
