// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

// L'aperçu SERVI d'une saisie (#129, #130, #135) : le mécanisme, écrit une fois
// (`EtatApercu`), et les conditions arbitrées le 11/11/2026 — délai, réponse périmée
// ignorée, dernière valeur gardée pendant l'attente, hors ligne, pas de redemande.
// Aucune horloge réelle : la pause est un sas que le test ouvre.

/// La pause du délai, tenue par le test : chaque demande y attend jusqu'à `ouvrir()`.
private actor Sas {
    private var enAttente: [CheckedContinuation<Void, Never>] = []

    func attendre() async { await withCheckedContinuation { enAttente.append($0) } }

    func ouvrir() {
        let attentes = enAttente
        enAttente = []
        for attente in attentes { attente.resume() }
    }

    var attentes: Int { enAttente.count }

    /// Rend la main quand `nombre` demandes attendent au sas.
    func attendreQue(_ nombre: Int) async {
        while enAttente.count < nombre { await Task.yield() }
    }
}

/// Le serveur des tests : il compte ce qu'on lui demande, et répond en capitales — sauf
/// pour une entrée retenue, qui ne répond qu'à `relacher`.
private actor Serveur {
    private(set) var demandes: [String] = []
    private var retenues: [String: CheckedContinuation<Void, Never>] = [:]
    private var aRetenir: Set<String> = []
    var echoue = false

    func retenir(_ entree: String) { aRetenir.insert(entree) }
    func echouer() { echoue = true }

    func relacher(_ entree: String) { retenues.removeValue(forKey: entree)?.resume() }

    func repondre(_ entree: String) async throws -> String {
        demandes.append(entree)
        if aRetenir.contains(entree) { await withCheckedContinuation { retenues[entree] = $0 } }
        if echoue { throw ErreurService.inattendue(500) }
        return entree.uppercased()
    }

    func estRetenue(_ entree: String) -> Bool { retenues[entree] != nil }
}

@MainActor
private func etat(connue: (String, String)? = nil, sas: Sas? = nil) -> EtatApercu<String, String> {
    let pause: @Sendable () async throws -> Void
    if let sas { pause = { await sas.attendre() } } else { pause = {} }
    return EtatApercu(connue: connue, pause: pause)
}

@MainActor
@Suite struct EtatApercuTests {
    @Test func leDelaiArbitreEst150Millisecondes() {
        #expect(ApercuSaisie.delai == .milliseconds(150))
    }

    @Test func uneRafaleDeFrappeFaitUneSeuleDemandeApresLeDelai() async throws {
        let sas = Sas()
        let serveur = Serveur()
        let apercu = etat(sas: sas)
        for entree in ["d", "du", "dup"] {
            apercu.saisie(entree, enLigne: true) { try await serveur.repondre($0) }
        }
        await sas.attendreQue(3)
        #expect(await serveur.demandes.isEmpty, "rien ne part avant la fin du délai")
        await sas.ouvrir()
        await apercu.demandeEnCours()
        #expect(await serveur.demandes == ["dup"], "les deux frappes d'avant sont annulées")
        #expect(apercu.valeur == "DUP")
    }

    @Test func uneReponsePerimeeEstIgnoree() async throws {
        let serveur = Serveur()
        await serveur.retenir("a")
        let apercu = etat()
        apercu.saisie("a", enLigne: true) { try await serveur.repondre($0) }
        while !(await serveur.estRetenue("a")) { await Task.yield() }
        // La saisie change pendant que le serveur répond à « a ».
        apercu.saisie("b", enLigne: true) { try await serveur.repondre($0) }
        await apercu.demandeEnCours()
        #expect(apercu.valeur == "B")
        await serveur.relacher("a")
        for _ in 0..<20 { await Task.yield() }
        #expect(apercu.valeur == "B", "la réponse de « a », arrivée après, ne remplace pas celle de « b »")
    }

    @Test func laDerniereValeurResteSansClignoterPendantLAttente() async throws {
        let sas = Sas()
        let serveur = Serveur()
        let apercu = etat(connue: ("jean", "Jean"), sas: sas)
        #expect(apercu.valeur == "Jean")
        apercu.saisie("jeanne", enLigne: true) { try await serveur.repondre($0) }
        await sas.attendreQue(1)
        #expect(apercu.valeur == "Jean", "pendant le délai et la demande, l'ancienne valeur reste — jamais nil")
        await sas.ouvrir()
        await apercu.demandeEnCours()
        #expect(apercu.valeur == "JEANNE")
    }

    @Test func horsLigneRienNePartEtLaValeurServieReste() async throws {
        let serveur = Serveur()
        let apercu = etat(connue: ("jean", "Jean"))
        apercu.saisie("jeanne", enLigne: false) { try await serveur.repondre($0) }
        await apercu.demandeEnCours()
        #expect(await serveur.demandes.isEmpty, "hors ligne, l'aperçu ne part pas")
        #expect(apercu.valeur == "Jean", "la dernière valeur servie reste")
        // Le réseau revient, la saisie n'a pas bougé : elle se demande alors.
        apercu.saisie("jeanne", enLigne: true) { try await serveur.repondre($0) }
        await apercu.demandeEnCours()
        #expect(await serveur.demandes == ["jeanne"])
        #expect(apercu.valeur == "JEANNE")
    }

    @Test func unEchecGardeLaValeurEtNeBloqueRien() async throws {
        let serveur = Serveur()
        await serveur.echouer()
        let apercu = etat(connue: ("jean", "Jean"))
        apercu.saisie("jeanne", enLigne: true) { try await serveur.repondre($0) }
        await apercu.demandeEnCours()
        #expect(apercu.valeur == "Jean", "refusée ou perdue, la demande laisse la valeur en place")
    }

    @Test func uneValeurDejaServieNeSeRedemandePas() async throws {
        let serveur = Serveur()
        let apercu = etat(connue: ("jean", "Jean"))
        // Servie avec l'objet : la saisie d'ouverture ne part pas.
        apercu.saisie("jean", enLigne: true) { try await serveur.repondre($0) }
        await apercu.demandeEnCours()
        #expect(await serveur.demandes.isEmpty)
        // Une entrée qui ne change pas ne repart pas ; une entrée déjà servie revient sans demande.
        apercu.saisie("paul", enLigne: true) { try await serveur.repondre($0) }
        apercu.saisie("paul", enLigne: true) { try await serveur.repondre($0) }
        await apercu.demandeEnCours()
        apercu.saisie("jean", enLigne: true) { try await serveur.repondre($0) }
        #expect(apercu.valeur == "Jean", "rendue sur-le-champ, sans délai")
        apercu.saisie("paul", enLigne: true) { try await serveur.repondre($0) }
        await apercu.demandeEnCours()
        #expect(await serveur.demandes == ["paul"], "une seule demande pour « paul », aucune pour « jean »")
        #expect(apercu.valeur == "PAUL")
    }
}

// MARK: - Les trois routes, par le client généré

@Suite struct ServiceApercusTests {
    @Test func lesDeuxServicesRealisentLesApercus() {
        let _: any ServiceApercus = ServiceAPI()
        let _: any ServiceApercus = ServiceSimule()
    }

    @Test func laLectureDUneSaisieEstCelleQueLeServeurSert() async throws {
        let lecture = try #require(Apercu.lecturesServies["copros"])
        let corps = #"{"lecture": \#(lecture), "destinataires_par_defaut": [], "lue_du_seul_conseil": false}"#
        let servie = try await ServiceAPI(transport: { _ in TransportFixe(corps: corps) })
            .lecture(de: SaisieLecture(categorie: "panne", perimetreCible: ["bat_a"]), dans: ServiceSimule.residence)
        #expect(servie.cle == "coproprietaires" && servie.court == "Copropriétaires")
    }

    @Test func leLieuEtLeNomDUneSaisieSontServis() async throws {
        let lieu = try await ServiceAPI(transport: { _ in
            TransportFixe(corps: #"{"libelle": "Bât. A › Toit", "badge": "Bât. A › Toit"}"#)
        }).lieu(de: ["bat_a/toit"], dans: ServiceSimule.residence)
        #expect(lieu == "Bât. A › Toit")
        let rendu = #"{"nom_affiche": "Jean-Baptiste FORT"}"#
        let nom = try await ServiceAPI(transport: { _ in TransportFixe(corps: rendu) })
            .nomAffiche(NomSaisi(prenom: "Jean-Baptiste", nom: "ForT"), dans: ServiceSimule.residence)
        #expect(nom == "Jean-Baptiste FORT", "le serveur nomme ; l'app ne met pas le nom en capitales")
    }

    @Test func uneSaisieSeRangeSousUneSeuleCle() {
        #expect(SaisieLecture(categorie: "panne", perimetreCible: ["b", "a"])
            == SaisieLecture(categorie: "panne", perimetreCible: ["a", "b"]), "deux ordres, une saisie")
    }

    @Test func lesReponsesSimuleesSeLisentParLeTypeGenere() throws {
        #expect(try FixturesApercus.lecture().cle == FixturesApercus.cleLecture)
        #expect(try FixturesApercus.lieu(["bat_a/toit"]) == "Bâtiment A › Toit")
        #expect(try FixturesApercus.lieu([FixturesApercus.codeParDefaut]) == "Toute la copropriété")
        #expect(try FixturesApercus.nom() == "Camille EXEMPLE")
    }
}
