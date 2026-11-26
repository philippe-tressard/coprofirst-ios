// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import CoproFirst

// Les notifications push côté app (#17, lot P3 de la spec push de coprofirst).

/// Vérifié à la compilation : `service.serviceAppareils` ne rend jamais `nil`.
@Test func lesDeuxServicesServentLesAppareils() {
    let services: [any ServiceAppareils] = [ServiceAPI(), ServiceSimule(delai: .zero)]
    #expect(services.count == 2)
}

// MARK: - Ce qui part chez l'installation

/// Un champ de `AppareilEnregistre`, lu dans le contrat embarqué — jamais recopié.
private func champDuContrat(_ champ: String) throws -> [String: Any] {
    let contrat = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Paquets/ClientAPI/Sources/ClientAPI/openapi.json")
    let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: contrat)) as? [String: Any])
    let schemas = (json["components"] as? [String: Any])?["schemas"] as? [String: Any]
    let proprietes = (schemas?["AppareilEnregistre"] as? [String: Any])?["properties"] as? [String: Any]
    return try #require(proprietes?[champ] as? [String: Any])
}

/// Depuis le contrat 2.4.0 (coprofirst#2789), le jeton n'a plus de motif au contrat : le
/// serveur le juge avec sa `plateforme` (`apns` par défaut). Le contrat n'en dit plus que la
/// longueur maximale — c'est elle qui se vérifie ici, avec le motif de l'abonnement.
@Test func lAbonnementEtLeJetonSuiventLeContrat() throws {
    let abonnement = try Regex(try #require(try champDuContrat("abonnement")["pattern"] as? String))
    let tires = (0..<50).map { _ in AbonnementsPush.tirer() }
    for tire in tires { #expect(tire.wholeMatch(of: abonnement) != nil, "abonnement hors du motif") }
    #expect(Set(tires).count == tires.count, "un tirage aléatoire, jamais deux fois le même")
    let longueur = try #require(try champDuContrat("jeton")["maxLength"] as? Int)
    let jeton = JetonAPNs(CentreSimule.jeton).hexadecimal.enClair
    #expect(!jeton.isEmpty && jeton.count <= longueur)
}

/// Un transport qui garde le corps envoyé, et répond 204.
private final class TransportEnregistreur: ClientTransport, @unchecked Sendable {
    var corps: Data?
    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws
        -> (HTTPResponse, HTTPBody?) {
        if let body { corps = try await Data(collecting: body, upTo: 4096) }
        return (HTTPResponse(status: .noContent), nil)
    }
}

@Test func lEnregistrementNEnvoieQueLesQuatreChampsDuContrat() async throws {
    let transport = TransportEnregistreur()
    let client = ClientCoproFirst.client(installation: URL(string: "https://demo.test")!, transport: transport)
    let appareil = AppareilPush(
        jeton: JetonAPNs(CentreSimule.jeton), environnement: .developpement, abonnement: AbonnementsPush.tirer())
    _ = try await client.postAppareils(body: .json(.init(appareil)))
    let corps = try #require(transport.corps)
    let envoye = try #require(try JSONSerialization.jsonObject(with: corps) as? [String: String])
    #expect(Set(envoye.keys) == ["plateforme", "jeton", "environnement", "abonnement"], "rien d'autre ne part (N5)")
    #expect(envoye["plateforme"] == "apns", "dite, même si le serveur la suppose (#283)")
    #expect(envoye["environnement"] == "developpement")
    #expect(envoye["jeton"] == appareil.jeton.hexadecimal.enClair)
    #expect(envoye["abonnement"] == appareil.abonnement)
}

/// Le jeton est un identifiant d'une personne (N8) : aucune de ses descriptions ne le montre.
@Test func leJetonNeSEcritJamais() {
    let jeton = JetonAPNs(CentreSimule.jeton)
    var vidage = ""
    dump(jeton, to: &vidage)
    let appareil = AppareilPush(jeton: jeton, environnement: .production, abonnement: "a")
    for texte in ["\(jeton)", String(reflecting: jeton), vidage, "\(appareil)", String(reflecting: appareil)] {
        #expect(!texte.contains(jeton.hexadecimal.enClair), "le jeton paraît dans « \(texte.prefix(40))… »")
        #expect(!texte.contains(String(jeton.hexadecimal.enClair.prefix(12))), "même tronqué")
    }
}

// MARK: - Le parcours

extension RelaisPush {
    /// Allumé, et la résidence inventée (au plancher) servie : le parcours se joue.
    fileprivate static let allumeAuPlancher = RelaisPush(allume: true, depuis: .plancher)
}

/// Une app neuve, la résidence inventée ouverte, l'autorisation donnée.
@MainActor
private struct AppOuverte {
    let parcours: Parcours
    let push: NotificationsPush
    let service = ServiceSimule(delai: .zero)
    let centre: CentreSimule
    let reglages: UserDefaults

    init(_ autorisation: AutorisationPush, relais: RelaisPush = .allumeAuPlancher) async {
        let suite = reglagesNeufs()
        reglages = suite
        parcours = Parcours(service: service, connues: InstallationsConnues(reglages: suite))
        centre = CentreSimule(autorisation)
        push = NotificationsPush(centre: centre, reglages: suite, environnement: .developpement, relais: relais)
        parcours.ouvrir(ServiceSimule.residence)
        await push.attacher(parcours)
    }
}

/// Des réglages vides, propres au test.
private func reglagesNeufs() -> UserDefaults {
    UserDefaults(suiteName: "push-tests-\(UUID().uuidString)") ?? .standard
}

/// Une autre résidence connue de l'appareil.
@MainActor
private func autreResidence(_ parcours: Parcours) -> Installation {
    var autre = ServiceSimule.residence
    autre.adresse = URL(string: "https://glycines.example.com") ?? autre.adresse
    parcours.connues.retenir(autre)
    return autre
}

/// Attend qu'une tâche détachée ait fait son effet (au plus deux secondes).
@MainActor
private func jusqua(_ condition: () -> Bool) async {
    for _ in 0..<200 where !condition() { try? await Task.sleep(for: .milliseconds(10)) }
}

@MainActor
@Test func rienNeSeDemandeNiNePartSansAccordDeLUtilisateur() async {
    let app = await AppOuverte(.nonDemandee)
    let push = app.push
    let service = app.service
    let centre = app.centre
    await push.residenceOuverte(ServiceSimule.residence)
    #expect(centre.demandes == 0, "jamais d'alerte système à l'ouverture")
    #expect(centre.inscriptions == 0)
    #expect(service.appareilsEnregistres(ServiceSimule.residence).isEmpty)
    #expect(push.offreDue, "l'offre attend dans la cloche")
}

@MainActor
@Test func activerDemandeUneFoisPuisEnregistreLAppareil() async throws {
    let app = await AppOuverte(.nonDemandee)
    let push = app.push
    let service = app.service
    let centre = app.centre
    await push.activer()
    #expect(centre.demandes == 1)
    #expect(push.autorisation == .accordee)
    #expect(!push.offreDue)
    await jusqua { !service.appareilsEnregistres(ServiceSimule.residence).isEmpty }
    let appareil = try #require(service.appareilsEnregistres(ServiceSimule.residence).first)
    #expect(appareil.environnement == .developpement)
    #expect(appareil.abonnement == push.abonnements.existant(pour: ServiceSimule.residence))
}

@MainActor
@Test func uneResidenceOuverteAvecLAccordEnregistreSansRedemander() async {
    let app = await AppOuverte(.accordee)
    let service = app.service
    let centre = app.centre
    await jusqua { !service.appareilsEnregistres(ServiceSimule.residence).isEmpty }
    #expect(service.appareilsEnregistres(ServiceSimule.residence).count == 1)
    #expect(centre.demandes == 0)
}

@MainActor
@Test func unRefusNeSeRedemandePas() async {
    let app = await AppOuverte(.refusee)
    let push = app.push
    let service = app.service
    #expect(!push.offreDue)
    #expect(service.appareilsEnregistres(ServiceSimule.residence).isEmpty)
}

@MainActor
@Test func plusTardTaitLOffreQuelquesJours() async {
    let app = await AppOuverte(.nonDemandee)
    let push = app.push
    push.reporter()
    #expect(!push.offreDue)
}

@MainActor
@Test func laDeconnexionRetireLAppareilAvantDeFermerLaSession() async {
    let app = await AppOuverte(.accordee)
    let parcours = app.parcours
    let push = app.push
    let service = app.service
    let residence = ServiceSimule.residence
    await jusqua { !service.appareilsEnregistres(residence).isEmpty }
    let abonnement = push.abonnements.existant(pour: residence)
    await parcours.deconnecter(residence)
    #expect(service.appareilsEnregistres(residence).isEmpty, "retiré tant que la session était ouverte")
    #expect(push.abonnements.existant(pour: residence) == nil)
    // Une notification qui arriverait encore ne mène plus à rien.
    push.touchee(abonnement: abonnement)
    #expect(parcours.porte.enAttente == nil)
    #expect(!parcours.clocheOuverte)
}

// MARK: - La notification touchée, reçue

@MainActor
@Test func toucherOuvreLaClocheDeLaResidenceOuverte() async {
    let app = await AppOuverte(.accordee)
    let parcours = app.parcours
    let push = app.push
    push.touchee(abonnement: push.abonnements.abonnement(pour: ServiceSimule.residence))
    #expect(parcours.clocheOuverte)
}

@MainActor
@Test func toucherPourUneAutreResidenceAttendQuElleSOuvre() async {
    let app = await AppOuverte(.accordee)
    let parcours = app.parcours
    let push = app.push
    let autre = autreResidence(parcours)
    parcours.ouvrir(ServiceSimule.residence)
    push.touchee(abonnement: push.abonnements.abonnement(pour: autre))
    #expect(parcours.ouverte == nil, "la résidence change : sa session d'abord")
    #expect(parcours.porte.enAttente?.adresse == autre.adresse)
    #expect(!parcours.clocheOuverte)
    parcours.ouvrir(autre)
    #expect(parcours.clocheOuverte, "la cloche s'ouvre à l'arrivée")
    #expect(parcours.porte.enAttente == nil)
}

@MainActor
@Test func uneDemandeTombeSiLUtilisateurVaAilleurs() async {
    let app = await AppOuverte(.accordee)
    let parcours = app.parcours
    let autre = autreResidence(parcours)
    parcours.suivre(Destination(adresse: autre.adresse, ecran: .notifications))
    #expect(parcours.porte.enAttente?.adresse == autre.adresse)
    parcours.ouvrir(ServiceSimule.residence)
    #expect(!parcours.clocheOuverte)
    #expect(parcours.porte.enAttente == nil)
}

@MainActor
@Test func uneResidenceInconnueNOuvreRien() async {
    let app = await AppOuverte(.accordee)
    let parcours = app.parcours
    let ouverte = parcours.ouverte
    let ailleurs = URL(string: "https://ailleurs.example.com") ?? ServiceSimule.residence.adresse
    #expect(!parcours.suivre(Destination(adresse: ailleurs, ecran: .notifications), decouvrir: false))
    #expect(parcours.ouverte == ouverte)
    #expect(parcours.porte.enAttente == nil)
    #expect(!parcours.clocheOuverte)
}

@MainActor
@Test func unAutreEcranDemandeRefermeLaCloche() async {
    let app = await AppOuverte(.accordee)
    let parcours = app.parcours
    let residence = ServiceSimule.residence.adresse
    parcours.suivre(Destination(adresse: residence, ecran: .notifications), decouvrir: false)
    #expect(parcours.clocheOuverte)
    parcours.suivre(Destination(adresse: residence, ecran: .element("ticket_ouvert:41")))
    #expect(!parcours.clocheOuverte, "la feuille ne cache pas l'élément demandé")
    #expect(parcours.aOuvrir == "ticket_ouvert:41")
}

/// La porte des liens (#18) pose la cloche par-dessus l'onglet en cours, quel qu'il soit.
@Test func laPorteAiguilleLesNotificationsVersLaCloche() {
    #expect(Aiguillage.aiguiller(.notifications, pages: ["tableau-de-bord"], visibles: 4) == .cloche)
}

@MainActor
@Test func uneNotificationToucheeAvantLeLancementAttendLApp() async {
    let suite = reglagesNeufs()
    let push = NotificationsPush(centre: CentreSimule(.accordee), reglages: suite, relais: .allumeAuPlancher)
    push.touchee(abonnement: push.abonnements.abonnement(pour: ServiceSimule.residence))
    let parcours = Parcours(service: ServiceSimule(delai: .zero), connues: InstallationsConnues(reglages: suite))
    parcours.ouvrir(ServiceSimule.residence)
    await push.attacher(parcours)
    #expect(parcours.clocheOuverte)
}

@MainActor
@Test func appOuverteLaBanniereNeSertQuAUneAutreResidence() async {
    let app = await AppOuverte(.accordee)
    let parcours = app.parcours
    let push = app.push
    let autre = autreResidence(parcours)
    #expect(push.presentation(abonnement: push.abonnements.abonnement(pour: ServiceSimule.residence)) == [.list])
    #expect(push.presentation(abonnement: push.abonnements.abonnement(pour: autre)) == [.banner, .list, .sound])
    #expect(push.presentation(abonnement: "inconnu") == [], "une résidence quittée ne sonne plus")
}

// MARK: - Le relais : éteint par défaut, et la porte de version (#283)

/// 🔴 Éteint tant que Philippe n'a pas allumé le service `notifications_push`
/// (coprofirst#2875) : l'allumer, c'est changer ce test, dans le lot qui le décide.
@Test func leRelaisEstEteintParDefaut() {
    #expect(!RelaisPush.courant.allume, "allumé sans la décision de Philippe (coprofirst#2875)")
    #expect(RelaisPush.courant.depuis == .plancher, "le contrat de l'alerte urgente est au plancher (#313)")
}

@MainActor
@Test func relaisEteintRienNeSeProposeNiNePart() async {
    let demandee = await AppOuverte(.nonDemandee, relais: .courant)
    #expect(!demandee.push.offreDue, "pas d'offre pour une alerte qui n'arrive pas")
    let accordee = await AppOuverte(.accordee, relais: .courant)
    await accordee.push.residenceOuverte(ServiceSimule.residence)
    await accordee.push.jetonRecu(CentreSimule.jeton)
    #expect(accordee.service.appareilsEnregistres(ServiceSimule.residence).isEmpty)
    #expect(accordee.centre.inscriptions == 0, "aucun jeton demandé à iOS")
}

/// Une résidence sous la porte, ou qui ne dit pas sa version, ne reçoit pas l'appareil :
/// elle pourrait faire sonner toute la cloche, pas seulement l'alerte urgente.
@Test func seuleUneResidenceAuDessusDeLaPorteRecoitLAppareil() {
    let relais = RelaisPush(allume: true, depuis: VersionContrat(2, 10, 0))
    var residence = ServiceSimule.residence
    for (servie, attendu) in [("2.10.0", true), ("2.11", true), ("2.9.0", false), ("2.8.0", false), ("2.x", false)] {
        residence.versionContrat = servie
        #expect(relais.sert(residence) == attendu, "contrat \(servie)")
    }
    residence.versionContrat = nil
    #expect(!relais.sert(residence), "version absente : les gestes du plancher")
    #expect(!relais.sert(nil), "aucune résidence ouverte")
    residence.versionContrat = "2.10.0"
    #expect(!RelaisPush(allume: false, depuis: .plancher).sert(residence), "éteint : rien")
}

@MainActor
@Test func sousLaPorteLOffreSeTaitEtRienNePart() async {
    // Une porte au-dessus du plancher, qu'aucune version servie n'atteint encore.
    let porte = VersionContrat(99, 0, 0)
    let sousLaPorte = RelaisPush(allume: true, depuis: porte)
    #expect(ServiceSimule.residence.contrat ?? .plancher < porte, "la résidence inventée sert le plancher")
    let demandee = await AppOuverte(.nonDemandee, relais: sousLaPorte)
    #expect(!demandee.push.offreDue)
    let accordee = await AppOuverte(.accordee, relais: sousLaPorte)
    await accordee.push.jetonRecu(CentreSimule.jeton)
    #expect(accordee.service.appareilsEnregistres(ServiceSimule.residence).isEmpty)
}

/// Éteint, la déconnexion retire encore l'appareil qu'une version précédente a enregistré.
@MainActor
@Test func relaisEteintLaDeconnexionRetireEncore() async {
    let app = await AppOuverte(.accordee)
    let residence = ServiceSimule.residence
    await jusqua { !app.service.appareilsEnregistres(residence).isEmpty }
    let eteint = NotificationsPush(
        centre: app.centre, reglages: app.reglages, environnement: .developpement, relais: .courant)
    await eteint.attacher(app.parcours)
    await app.parcours.deconnecter(residence)
    #expect(app.service.appareilsEnregistres(residence).isEmpty, "retiré, relais éteint")
}
