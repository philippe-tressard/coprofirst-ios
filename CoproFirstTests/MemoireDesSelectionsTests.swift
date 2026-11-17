// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

// L'élément ouvert d'une liste, hors de l'écran qui la montre (#119) : par page ET par liste,
// effacé par un nil voulu, gardé sur disque pour le pliable seul, effacé à la déconnexion.

private typealias Cle = MemoireDesSelections.Cle

@MainActor
private func parcours(_ posture: Posture) -> (Parcours, MarquesPages) {
    let suite = "fr.coprofirst.tests.selections.\(UUID().uuidString)"
    let reglages = UserDefaults(suiteName: suite) ?? .standard
    reglages.removePersistentDomain(forName: suite)
    let marques = MarquesPages(reglages: reglages)
    let parcours = Parcours(
        service: ServiceSimule(delai: .zero),
        connues: InstallationsConnues(reglages: reglages, coffre: CoffreEnMemoire()), marques: marques)
    parcours.posture = posture
    parcours.ouvrir(ServiceSimule.residence)
    return (parcours, marques)
}

@MainActor @Suite struct MemoireDesSelectionsTests {
    private let courriels = Cle(page: "espace-cs", liste: "courriels")
    private let reporting = Cle(page: "espace-cs", liste: "reporting")

    /// Deux listes d'une même page, du même type d'élément : chacune retrouve LE SIEN.
    @Test func laCleEstLaPageEtLaListe() {
        let memoire = MemoireDesSelections()
        memoire.noter(AffaireAOuvrir(id: 41), sous: courriels)
        #expect(memoire.reprendre(AffaireAOuvrir.self, sous: courriels) == AffaireAOuvrir(id: 41))
        #expect(memoire.reprendre(AffaireAOuvrir.self, sous: reporting) == nil, "pas l'affaire d'une autre liste")
        #expect(memoire.reprendre(String.self, sous: courriels) == nil, "pas un élément d'un autre type")
    }

    @Test func unNilVouluEffaceLaCase() {
        let memoire = MemoireDesSelections()
        memoire.noter(AffaireAOuvrir(id: 41), sous: courriels)
        memoire.noter(AffaireAOuvrir?.none, sous: courriels)
        #expect(memoire.reprendre(AffaireAOuvrir.self, sous: courriels) == nil, "une liste vidée ne rouvre rien")
    }

    @Test func uneAutreResidenceNHeriteDeRien() {
        let (plie, _) = parcours(.plie)
        plie.selections.noter(AffaireAOuvrir(id: 41), sous: courriels)
        plie.ouvrir(ServiceSimule.demo)
        #expect(plie.selections.reprendre(AffaireAOuvrir.self, sous: courriels) == nil)
    }

    @Test func unIPhoneSansCharniereNEcritRienSurDisque() {
        let (iphone, marques) = parcours(.sansPli)
        iphone.selections.noter(AffaireAOuvrir(id: 41), sous: courriels)
        #expect(marques.lire(courriels, pour: ServiceSimule.residence.hote) == nil)
    }

    /// Sur un pliable, l'affaire se garde par son numéro seul, et se rouvre après un arrêt
    /// de l'app (une mémoire neuve) ; un élément qui ne sait pas se réécrire reste en mémoire.
    @Test func unPliableGardeSurDisqueCeQuiSeReecrit() {
        let (plie, marques) = parcours(.plie)
        plie.selections.noter(AffaireAOuvrir(id: 41), sous: courriels)
        #expect(marques.lire(courriels, pour: ServiceSimule.residence.hote) == "41", "le numéro, rien d'autre")

        let apresArret = MemoireDesSelections()
        apresArret.disque = plie.disqueDesSelections
        #expect(apresArret.reprendre(AffaireAOuvrir.self, sous: courriels) == AffaireAOuvrir(id: 41))

        plie.selections.noter(AffaireAOuvrir?.none, sous: courriels)
        #expect(marques.lire(courriels, pour: ServiceSimule.residence.hote) == nil, "le nil efface aussi le disque")
    }

    @Test func uneAffaireSeReecritParSonNumero() {
        #expect(AffaireAOuvrir(id: 41).cleGardee == "41")
        #expect(AffaireAOuvrir(cleGardee: "41") == AffaireAOuvrir(id: 41))
        #expect(AffaireAOuvrir(cleGardee: "quarante") == nil)
    }

    /// L'effacement d'une résidence emporte sa page et toutes ses listes, et rien d'un hôte
    /// dont le nom commence pareil.
    @Test func effacerUnHoteNEffaceQueLui() {
        let suite = "fr.coprofirst.tests.selections.\(UUID().uuidString)"
        let marques = MarquesPages(reglages: UserDefaults(suiteName: suite) ?? .standard)
        marques.garder("espace-cs", pour: "a.example.com")
        marques.garder("41", courriels, pour: "a.example.com")
        marques.garder("7", courriels, pour: "a.example.com.autre")
        marques.effacer("a.example.com")
        #expect(marques.lire("a.example.com") == nil)
        #expect(marques.lire(courriels, pour: "a.example.com") == nil)
        #expect(marques.lire(courriels, pour: "a.example.com.autre") == "7", "un autre hôte garde le sien")
    }
}
