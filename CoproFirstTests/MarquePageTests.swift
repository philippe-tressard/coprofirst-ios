// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

// Le marque-page du carnet (#119, décision du 17/11/2026) : la page ouverte d'une
// résidence, gardée sur l'appareil quand une charnière est présente, et effacée à la
// déconnexion. Un iPhone ordinaire n'écrit rien et rouvre sur le Fil.

/// Des réglages jetables, et le parcours d'une résidence qui sert la barre par défaut.
@MainActor
private func parcours(_ posture: Posture, marques: MarquesPages? = nil) -> (Parcours, MarquesPages) {
    let suite = "fr.coprofirst.tests.marque-page.\(UUID().uuidString)"
    let reglages = UserDefaults(suiteName: suite) ?? .standard
    reglages.removePersistentDomain(forName: suite)
    let marques = marques ?? MarquesPages(reglages: reglages)
    let parcours = Parcours(
        service: ServiceSimule(delai: .zero),
        connues: InstallationsConnues(reglages: reglages, coffre: CoffreEnMemoire()), marques: marques)
    parcours.posture = posture
    return (parcours, marques)
}

@MainActor @Suite struct MarquePageTests {
    private let residence = ServiceSimule.residence

    @Test func unIPhoneSansCharniereNEcritRienEtRouvreSurLeFil() {
        let (iphone, marques) = parcours(.sansPli)
        iphone.ouvrir(residence)
        iphone.onglet = "faq"
        iphone.onglet = Aiguillage.idPlus
        iphone.ouverteDansPlus = "communaute"
        #expect(marques.lire(residence.hote) == nil, "sans charnière, rien ne s'écrit sur l'appareil")

        marques.garder("faq", pour: residence.hote)
        let (rouvert, _) = parcours(.sansPli, marques: marques)
        rouvert.ouvrir(residence)
        #expect(rouvert.onglet == OrdrePages.idFil, "même un marque-page présent ne se lit pas sans charnière")
    }

    @Test func unPliableRouvreSurLaPageOuverte() {
        let (plie, marques) = parcours(.plie)
        plie.ouvrir(residence)
        plie.onglet = "mon-lot"
        #expect(marques.lire(residence.hote) == "mon-lot")

        let (rouvert, _) = parcours(.plie, marques: marques)
        rouvert.ouvrir(residence)
        #expect(rouvert.onglet == "mon-lot", "après un arrêt par iOS : la même page")
    }

    @Test func laPageOuverteDansPlusSeNoteEtSeRouvreDansLeCarnet() {
        let (plie, marques) = parcours(.plie)
        plie.ouvrir(residence)
        plie.onglet = Aiguillage.idPlus
        #expect(marques.lire(residence.hote) == OrdrePages.idFil, "« Plus » seul n'est pas une page : le Fil reste")
        plie.ouverteDansPlus = "faq"
        #expect(marques.lire(residence.hote) == "faq")

        let (deplie, _) = parcours(.deplie, marques: marques)
        deplie.presenter(.carnet)
        deplie.ouvrir(residence)
        #expect(deplie.onglet == "faq", "dans le carnet, son intercalaire")

        let (replie, _) = parcours(.plie, marques: marques)
        replie.ouvrir(residence)
        #expect(
            replie.onglet == Aiguillage.idPlus && replie.ouverteDansPlus == "faq",
            "dans la barre du bas, au-delà des quatre : rouverte dans « Plus »")
    }

    @Test func unePageQuiNEstPlusOfferteRouvreSurLeFil() {
        let (plie, marques) = parcours(.plie)
        marques.garder("page-retiree", pour: residence.hote)
        plie.ouvrir(residence)
        #expect(plie.onglet == OrdrePages.idFil)
    }

    @Test func leMarquePageEstParResidence() {
        let (plie, marques) = parcours(.plie)
        plie.ouvrir(residence)
        plie.onglet = "faq"
        #expect(marques.lire(ServiceSimule.demo.hote) == nil)
        plie.ouvrir(ServiceSimule.demo)
        #expect(plie.onglet == OrdrePages.idFil, "une autre résidence n'hérite pas du marque-page")
    }

    /// La porte de tout ce qu'une session laisse l'efface avec le jeton et la lecture gardée.
    @Test func laPorteDeLEffacementEmporteLeMarquePage() {
        let hote = "marque-page-\(UUID().uuidString).example.com"
        MarquesPages.standard.garder("faq", pour: hote)
        ServiceAPI.oublierCeQuiEstGarde(hote, MagasinDeTest().magasin())
        #expect(MarquesPages.standard.lire(hote) == nil)
    }

    @Test func laDeconnexionSimuleeLEmporteAussi() async {
        let (plie, marques) = parcours(.plie)
        let simule = plie.service as? ServiceSimule
        simule?.marques = marques
        simule?.garder(residence)
        plie.ouvrir(residence)
        plie.onglet = "faq"
        _ = await plie.service.deconnecter(residence)
        #expect(marques.lire(residence.hote) == nil)
    }
}
