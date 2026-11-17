// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import Testing

@testable import CoproFirst

#if compiler(>=6.4)
import UIKit
#endif

// Le carnet de l'iPhone pliable ouvert (#119) : une présentation de plus de la navigation,
// choisie sur la classe de taille ET la charnière, jamais sur l'appareil.

private let pages = ["tableau-de-bord", "residence", "mes-demandes", "mon-lot", "annuaire", "faq", "communaute"]
private typealias Place = PresentationNavigation.Place

struct CarnetTests {
    @Test func laCharniereOuverteFaitLeCarnetEnClasseReguliereSeulement() {
        #expect(PresentationNavigation.pour(.regular, posture: .deplie) == .carnet)
        #expect(PresentationNavigation.pour(.regular, posture: .entrouvert) == .carnet, "ouvert comme un livre")
        #expect(PresentationNavigation.pour(.regular, posture: .sansPli) == .barreLaterale, "l'iPad")
        #expect(PresentationNavigation.pour(.regular, posture: .plie) == .barreLaterale)
        #expect(
            PresentationNavigation.pour(.compact, posture: .deplie) == .barreDuBas,
            "déplié mais étroit (Split View) : la barre du bas, qui tient partout")
        #expect(PresentationNavigation.pour(nil, posture: .deplie) == .barreDuBas)
        #expect(PresentationNavigation.pour(.regular) == .barreLaterale, "sans posture lue : pas de carnet")
    }

    @Test func leCarnetMontreToutesLesPagesSansPlus() {
        #expect(PresentationNavigation.carnet.visibles == .max)
        let toutes = PagesParDefaut.toutes.map(\.id)
        for id in toutes {
            #expect(
                Aiguillage.aiguiller(.page(id), pages: toutes, visibles: PresentationNavigation.carnet.visibles)
                    == .onglet(id), "\(id) : son intercalaire, jamais « Plus »")
        }
    }

    @Test func deplierPuisReplierRendLaMemePage() {
        for onglet in pages + EntreeFixe.allCases.map(\.rawValue) {
            let carnet = PresentationNavigation.traduire(Place(onglet: onglet), vers: .carnet, pages: pages)
            #expect(carnet == Place(onglet: onglet), "déplié : \(onglet) reste ouverte")
            let plie = PresentationNavigation.traduire(carnet, vers: .barreDuBas, pages: pages)
            let rouvert = PresentationNavigation.traduire(plie, vers: .carnet, pages: pages)
            #expect(rouvert == Place(onglet: onglet), "replié puis rouvert : \(onglet)")
        }
        let dansPlus = Place(onglet: Aiguillage.idPlus, dansPlus: "faq")
        #expect(
            PresentationNavigation.traduire(dansPlus, vers: .carnet, pages: pages) == Place(onglet: "faq"),
            "ouverte dans « Plus » : son intercalaire")
        #expect(
            PresentationNavigation.traduire(Place(onglet: Aiguillage.idPlus), vers: .carnet, pages: pages)
                == Place(onglet: "annuaire"), "« Plus » seul : la première page qu'il portait")
    }

    /// À la taille par défaut, chaque libellé de page tient sur la tranche sans rapetisser ni
    /// se couper : « Communau-té » s'y lisait à 76 pt (capture du 17/11/2026).
    @Test func lesLibellesParDefautTiennentEntiersSurLaTranche() {
        let place = Mise.tranche - 2 * Intercalaires.retrait
        let libelles = PagesParDefaut.toutes.map(\.libelle) + EntreeFixe.allCases.map(\.libelle)
        for libelle in libelles {
            let mot = TexteSansCoupure.plusLongMot(libelle)
            #expect(
                TexteSansCoupure.largeurDe(mot, en: .large, style: .caption2) <= place,
                "« \(mot) » (\(libelle)) dépasse la tranche à la taille par défaut")
        }
        #expect(
            TexteSansCoupure.taille(
                pour: "Administration-générale", dans: place, depuis: .large, plancher: .xSmall, style: .caption2)
                < .large, "un nom renommé trop long descend sous la taille par défaut plutôt que de se couper")
    }

    @Test func seulsLOuvertEtLEntrouvertSontOuverts() {
        #expect(Posture.deplie.ouverte)
        #expect(Posture.entrouvert.ouverte)
        #expect(!Posture.plie.ouverte)
        #expect(!Posture.sansPli.ouverte)
    }

    @Test func laPostureSeFixeEnDebugSousLApiSimuleeSeulement() {
        #expect(LancementSimule.posture(["-api-simulee", "-posture", "deplie"]) == .deplie)
        #expect(LancementSimule.posture(["-api-simulee", "-posture", "entrouvert"]) == .entrouvert)
        #expect(LancementSimule.posture(["-api-simulee", "-posture", "plie"]) == .plie)
        #expect(
            LancementSimule.posture(["-api-simulee", "-posture", "ouvert"]) == nil, "valeur inconnue : rien de fixé")
        #expect(
            LancementSimule.posture(["-posture", "deplie"]) == nil, "hors de l'API simulée : la vraie charnière")
    }

    #if compiler(>=6.4)
    /// Au poste seulement (Xcode 27) : la CI n'a pas `UIHinge`.
    @available(iOS 27.1, *)
    @Test func lEtatDeLaCharniereDevientLaPosture() {
        #expect(Posture(UIHinge.Status.closed) == .plie)
        #expect(Posture(UIHinge.Status.partiallyOpen) == .entrouvert)
        #expect(Posture(UIHinge.Status.fullyOpen) == .deplie)
        #expect(Posture(UIHinge.Status.unknown) == .sansPli)
        #expect(Posture(nil) == .sansPli, "sans charnière : ni iPad ni iPhone n'ouvrent le carnet")
    }
    #endif
}
