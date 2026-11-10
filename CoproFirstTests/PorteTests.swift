// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

// La porte de navigation (#18, partagée avec les notifications #17) : un lien devient
// une destination, et une seule porte l'ouvre.

private let tilleuls = ServiceSimule.residence
private let affaires = "mes-demandes"

private func lien(_ texte: String) throws -> Destination {
    let url = try #require(URL(string: texte))
    return try #require(LienUniversel.destination(url))
}

// MARK: - Les chemins de l'AASA servi par les installations (coprofirst#2459)

@Test func chaqueCheminDeLAASAMeneASonEcran() throws {
    #expect(try lien("https://tilleuls.exemple.fr/").ecran == .accueil)
    #expect(try lien("https://tilleuls.exemple.fr").ecran == .accueil, "le QR de la fiche d'arrivée")
    #expect(try lien("https://tilleuls.exemple.fr/tickets").ecran == .page(affaires))
    #expect(try lien("https://tilleuls.exemple.fr/tickets/23").ecran == .affaire(id: 23, message: nil))
    #expect(try lien("https://tilleuls.exemple.fr/tickets/23#msg-45").ecran == .affaire(id: 23, message: 45))
    #expect(try lien("https://tilleuls.exemple.fr/auth/connexion").ecran == .connexion)
}

@Test func lesActualitesSontLaVueAffaires() throws {
    #expect(try lien("https://tilleuls.exemple.fr/actualites").ecran == .page(affaires))
    #expect(try lien("https://tilleuls.exemple.fr/actualites#pub-7").ecran == .page(affaires))
}

@Test func unLienAJetonSOuvreDansSafariIntegreAvecSonJeton() throws {
    for texte in [
        "https://tilleuls.exemple.fr/auth/verifier-email?token=abc",
        "https://tilleuls.exemple.fr/auth/reinitialisation-mdp?token=abc",
    ] {
        let url = try #require(URL(string: texte))
        #expect(try lien(texte).ecran == .navigateur(url), "le jeton n'est pas perdu")
    }
}

@Test func unCheminInconnuOuMalFormeResteAuSite() throws {
    let inconnu = try #require(URL(string: "https://tilleuls.exemple.fr/mentions-legales"))
    #expect(try lien(inconnu.absoluteString).ecran == .navigateur(inconnu))
    let illisible = try #require(URL(string: "https://tilleuls.exemple.fr/tickets/abc"))
    #expect(try lien(illisible.absoluteString).ecran == .navigateur(illisible))
}

@Test func uneRouteDuMenuOuvreSaPage() throws {
    #expect(try lien("https://tilleuls.exemple.fr/annuaire").ecran == .page("annuaire"))
}

@Test func lAdresseEstCelleDUneInstallation() throws {
    #expect(try lien("https://TILLEULS.exemple.fr/tickets/1").adresse == tilleuls.adresse, "hôte normalisé")
    let avecPort = try lien("https://essai.exemple.fr:8443/")
    #expect(avecPort.adresse.absoluteString == "https://essai.exemple.fr:8443")
    #expect(AdresseInstallation.enSaisie(avecPort.adresse) == "essai.exemple.fr:8443")
}

@Test func seulHTTPSPasse() throws {
    for texte in ["http://tilleuls.exemple.fr/tickets/1", "coprofirst://tilleuls.exemple.fr/", "https:///tickets/1"] {
        let url = try #require(URL(string: texte))
        #expect(LienUniversel.destination(url) == nil, "\(texte)")
    }
}

// MARK: - L'aiguillage dans la résidence ouverte

@Test func unePageSePoseDansLaBarrePlusOuSurLeFil() {
    let pages = ["tableau-de-bord", "residence", affaires, "mon-lot", "annuaire", "faq"]
    #expect(Aiguillage.aiguiller(.page("residence"), pages: pages, visibles: 4) == .onglet("residence"))
    #expect(Aiguillage.aiguiller(.page("faq"), pages: pages, visibles: 4) == .onglet(Aiguillage.idPlus))
    #expect(
        Aiguillage.aiguiller(.page("admin"), pages: pages, visibles: 4) == .onglet(OrdrePages.idFil),
        "une page réservée que le compte ne voit pas")
    #expect(Aiguillage.aiguiller(.connexion, pages: pages, visibles: 4) == .onglet(OrdrePages.idFil))
}

@Test func uneAffaireSOuvreDansSonOngletSinonEnFeuille() {
    let affaire = Destination.Ecran.affaire(id: 41, message: nil)
    #expect(
        Aiguillage.aiguiller(affaire, pages: ["tableau-de-bord", affaires], visibles: 4)
            == .affaireDansLOnglet(onglet: affaires, id: 41))
    let auDela = ["tableau-de-bord", "residence", "mon-lot", "annuaire", affaires]
    #expect(Aiguillage.aiguiller(affaire, pages: auDela, visibles: 4) == .affaireEnFeuille(id: 41))
    #expect(Aiguillage.aiguiller(affaire, pages: ["tableau-de-bord"], visibles: 4) == .affaireEnFeuille(id: 41))
}

// MARK: - La porte : résidence ouverte, connue, ou jamais vue

@MainActor
private func parcoursDeTest(ouverte: Installation? = nil, connues: [Installation] = []) throws -> Parcours {
    let reglages = try #require(UserDefaults(suiteName: "tests.\(UUID().uuidString)"))
    let parcours = Parcours(
        service: ServiceSimule(delai: .milliseconds(1)), connues: InstallationsConnues(reglages: reglages))
    connues.forEach(parcours.connues.retenir)
    if let ouverte { parcours.ouvrir(ouverte) }
    return parcours
}

@MainActor @Test func dansLaResidenceOuverteLEcranSOuvreAussitot() throws {
    let parcours = try parcoursDeTest(ouverte: tilleuls)
    parcours.suivre(try lien("https://tilleuls.exemple.fr/tickets/41"))
    #expect(parcours.ouverte == tilleuls)
    #expect(parcours.onglet == affaires)
    #expect(parcours.porte.affaireDansLOnglet == 41)
    #expect(parcours.porte.enAttente == nil)
}

@MainActor @Test func uneAffaireHorsDeLaBarreSOuvreEnFeuille() throws {
    var residence = tilleuls
    residence.ordrePages = ["tableau-de-bord", "residence", "mon-lot", "annuaire", affaires]
    let parcours = try parcoursDeTest(ouverte: residence)
    parcours.suivre(try lien("https://tilleuls.exemple.fr/tickets/41"))
    #expect(parcours.porte.affaireEnFeuille?.id == 41)
    #expect(parcours.onglet == OrdrePages.idFil, "l'onglet ne change pas sous la feuille")
}

@MainActor @Test func uneResidenceConnueSeRouvreParSaConnexionPuisMontreLEcran() throws {
    let autre = ServiceSimule.demo
    let parcours = try parcoursDeTest(ouverte: autre, connues: [tilleuls])
    let destination = try lien("https://tilleuls.exemple.fr/tickets/41")
    parcours.suivre(destination)
    #expect(parcours.ouverte == nil, "le lien vise une autre résidence")
    #expect(parcours.reconnue == tilleuls)
    #expect(parcours.chemin == [.connexion(.init(installation: tilleuls))])
    #expect(parcours.porte.enAttente == destination)
    parcours.ouvrir(tilleuls)  // Face ID ou mot de passe
    #expect(parcours.onglet == affaires)
    #expect(parcours.porte.affaireDansLOnglet == 41)
    #expect(parcours.porte.enAttente == nil)
}

@MainActor @Test func unHoteJamaisVuPasseParLaConnexionPreRemplieVenueDUnLien() throws {
    let parcours = try parcoursDeTest(ouverte: tilleuls)
    let destination = try lien("https://inconnue.exemple.org/tickets/3")
    parcours.suivre(destination)
    #expect(parcours.ouverte == nil)
    #expect(parcours.reconnue == nil, "aucune palette ni nom avant la découverte")
    #expect(
        parcours.chemin == [.connexion(.init(adresse: destination.adresse, origine: .lien))],
        "l'hôte se confirme comme après un scan (#82)")
    #expect(parcours.connues.liste.contains { $0.adresse == destination.adresse } == false, "rien n'est retenu")
}

@MainActor @Test func unLienEnAttenteNeSuitPasUneAutreResidence() throws {
    let parcours = try parcoursDeTest(connues: [tilleuls])
    parcours.suivre(try lien("https://tilleuls.exemple.fr/tickets/41"))
    parcours.ouvrir(ServiceSimule.demo)
    #expect(parcours.onglet == OrdrePages.idFil)
    #expect(parcours.porte.affaireDansLOnglet == nil)
    #expect(parcours.porte.enAttente == nil, "abandonné, il ne ressort pas plus tard")
}

@MainActor @Test func auLancementLeRetourNOuvrePasUneAutreResidenceQueCelleDuLien() throws {
    let parcours = try parcoursDeTest(connues: [ServiceSimule.demo, tilleuls])
    parcours.suivre(try lien("https://tilleuls.exemple.fr/tickets/41"))
    #expect(parcours.ouvertureLibre(ServiceSimule.demo) == false, "le Face ID d'office de la dernière résidence attend")
    #expect(parcours.ouvertureLibre(tilleuls))
    parcours.chemin = []  // l'utilisateur revient de la connexion du lien
    #expect(parcours.porte.enAttente == nil)
    #expect(parcours.ouvertureLibre(ServiceSimule.demo))
}

@MainActor @Test func unElementDuFilSOuvreDepuisLeFil() throws {
    let sondage = Aiguillage.aiguiller(.element("sondage_ouvert:7"), pages: [affaires], visibles: 4)
    #expect(sondage == .elementDuFil("sondage_ouvert:7"))
    let parcours = try parcoursDeTest(ouverte: tilleuls)
    parcours.onglet = affaires
    parcours.suivre(Destination(adresse: tilleuls.adresse, ecran: .element("ticket_ouvert:41")))
    #expect(parcours.onglet == OrdrePages.idFil)
    #expect(parcours.aOuvrir == "ticket_ouvert:41")
}

@MainActor @Test func unLienDeConnexionVersLaResidenceOuverteMeneAuFil() throws {
    let parcours = try parcoursDeTest(ouverte: tilleuls)
    parcours.onglet = affaires
    parcours.suivre(try lien("https://tilleuls.exemple.fr/auth/connexion"))
    #expect(parcours.ouverte == tilleuls)
    #expect(parcours.onglet == OrdrePages.idFil)
}

@MainActor @Test func unLienAJetonNeQuittePasLaResidence() throws {
    let parcours = try parcoursDeTest(ouverte: tilleuls)
    let url = try #require(URL(string: "https://inconnue.exemple.org/auth/verifier-email?token=abc"))
    parcours.suivre(try #require(LienUniversel.destination(url)))
    #expect(parcours.porte.pageWeb?.url == url)
    #expect(parcours.ouverte == tilleuls)
}
