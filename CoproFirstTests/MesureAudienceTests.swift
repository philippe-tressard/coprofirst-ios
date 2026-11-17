// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import CoproFirst

// La mesure d'audience de l'app (coprofirst#2726) : ce qui se note, quand ça part, ce qui
// ne part jamais — et ce que le corps envoyé porte.

/// Un service qui garde chaque lot reçu, par résidence ; `echoue` : il lève à chaque envoi.
private actor Enregistreur: ServiceAudience {
    private(set) var lots: [(hote: String, pages: [String])] = []
    let echoue: Bool

    init(echoue: Bool = false) { self.echoue = echoue }

    func envoyer(_ pages: [String], a installation: Installation) async throws {
        lots.append((installation.hote, pages))
        if echoue { throw ErreurService.inattendue(500) }
    }

    /// Attend qu'un lot arrive : un état, jamais une durée fixe.
    func attendreUnLot() async -> Bool {
        for _ in 0..<400 where lots.isEmpty { try? await Task.sleep(for: .milliseconds(5)) }
        return !lots.isEmpty
    }
}

/// Une résidence qui sert `contrat`, ouverte par un compte dont le refus est `refus`.
private func residence(
    _ hote: String = "demo.exemple", contrat: String? = VersionContrat.plancher.description, refus: Bool? = false
) -> Installation {
    var installation = Installation(
        adresse: URL(string: "https://\(hote)") ?? ServiceSimule.residence.adresse, nom: "Les Tilleuls",
        aUnLogo: false, versionContrat: contrat)
    installation.profil = ProfilResidence(statut: "locataire", roles: [], refusMesure: refus)
    return installation
}

@MainActor
private func mesure(
    _ service: any ServiceAudience, ouverte: Installation?, intervalle: Duration = .seconds(30)
) -> MesureAudience {
    let mesure = MesureAudience(service: service, intervalle: intervalle)
    mesure.courante = { ouverte }
    return mesure
}

@MainActor
struct MesureAudienceTests {
    @Test func laFilePartDesQuElleAtteintLaBorneDuContrat() async {
        let enregistreur = Enregistreur()
        let mesure = mesure(enregistreur, ouverte: residence())
        for i in 1...LimitesAudience.evenementsParLot { mesure.noter("/tickets/\(i)") }
        #expect(await enregistreur.attendreUnLot())
        let lots = await enregistreur.lots
        #expect(lots.count == 1)
        #expect(lots.first?.pages.count == LimitesAudience.evenementsParLot)
        #expect(mesure.file.isEmpty)
    }

    @Test func laFilePartAuBoutDuDelai() async {
        let enregistreur = Enregistreur()
        let mesure = mesure(enregistreur, ouverte: residence(), intervalle: .milliseconds(20))
        mesure.noter("/tableau-de-bord")
        #expect(await enregistreur.attendreUnLot(), "la minuterie a vidé la file")
        #expect(await enregistreur.lots.first?.pages == ["/tableau-de-bord"])
    }

    @Test func viderEnvoieParLotsALaBorne() async {
        let enregistreur = Enregistreur()
        let mesure = mesure(enregistreur, ouverte: residence())
        // Une file plus longue que la borne ne part jamais d'un seul lot (422 en bloc).
        for i in 1..<LimitesAudience.evenementsParLot { mesure.noter("/a/\(i)") }
        await mesure.vider()
        mesure.noter("/b")
        await mesure.vider()
        let tailles = await enregistreur.lots.map(\.pages.count)
        #expect(tailles == [LimitesAudience.evenementsParLot - 1, 1])
        #expect(tailles.allSatisfy { $0 <= LimitesAudience.evenementsParLot })
    }

    @Test(arguments: [true, nil] as [Bool?])
    func unRefusOuUnRefusInconnuNeNoteRien(_ refus: Bool?) async {
        let enregistreur = Enregistreur()
        let mesure = mesure(enregistreur, ouverte: residence(refus: refus))
        mesure.noter("/tickets")
        await mesure.vider()
        #expect(mesure.file.isEmpty)
        #expect(await enregistreur.lots.isEmpty)
    }

    /// Une installation antérieure ignorerait le canal : les vues de l'app y passeraient pour
    /// celles du site. Sous le plancher, ou sans version lisible, rien ne part : la porte de
    /// confidentialité reste fermée sur ce qu'on ne sait pas (#254).
    @Test(arguments: ["1.30.0", "1.27.0", "2.0.0", "illisible", nil] as [String?])
    func uneInstallationAnterieureNeNoteRien(_ contrat: String?) async {
        let enregistreur = Enregistreur()
        let mesure = mesure(enregistreur, ouverte: residence(contrat: contrat))
        mesure.noter("/tickets")
        await mesure.vider()
        #expect(await enregistreur.lots.isEmpty)
    }

    @Test func horsLigneOuSansResidenceRienNeSeNote() async {
        let enregistreur = Enregistreur()
        let mesure = mesure(enregistreur, ouverte: nil)
        mesure.noter("/tickets")
        #expect(mesure.file.isEmpty)
    }

    @Test func unePageVideOuTropLongueNeSeMetPasDansLaFile() {
        let mesure = mesure(Enregistreur(), ouverte: residence())
        mesure.noter("")
        mesure.noter("/" + String(repeating: "a", count: LimitesAudience.page))
        let juste = "/" + String(repeating: "a", count: LimitesAudience.page - 1)
        mesure.noter(juste)
        #expect(mesure.file == [juste])
    }

    @Test func leRefusPoseAvantLEnvoiJetteLaFile() async {
        let enregistreur = Enregistreur()
        var ouverte = residence()
        let mesure = MesureAudience(service: enregistreur)
        mesure.courante = { ouverte }
        mesure.noter("/tickets")
        ouverte.profil?.refusMesure = true
        await mesure.vider()
        #expect(await enregistreur.lots.isEmpty, "on ne collecte pas ce que le serveur jetterait")
    }

    @Test func changerDeResidenceEnvoieLaFileChezLaResidenceQuittee() async {
        let enregistreur = Enregistreur()
        var ouverte = residence("a.exemple")
        let mesure = MesureAudience(service: enregistreur)
        mesure.courante = { ouverte }
        mesure.noter("/tickets/1")
        ouverte = residence("b.exemple")
        mesure.noter("/annuaire")
        #expect(await enregistreur.attendreUnLot())
        let lots = await enregistreur.lots
        #expect(lots.map(\.hote) == ["a.exemple"])
        #expect(lots.first?.pages == ["/tickets/1"])
        #expect(mesure.file == ["/annuaire"], "la note neuve reste pour la résidence ouverte")
    }

    @Test func unEchecNeSeDitPasEtNeSeRejouePas() async {
        let enregistreur = Enregistreur(echoue: true)
        let mesure = mesure(enregistreur, ouverte: residence())
        mesure.noter("/tickets")
        await mesure.vider()
        await mesure.vider()
        #expect(await enregistreur.lots.count == 1)
        #expect(mesure.file.isEmpty)
    }

    @Test func oublierJetteLaFile() async {
        let enregistreur = Enregistreur()
        let mesure = mesure(enregistreur, ouverte: residence())
        mesure.noter("/tickets")
        mesure.oublier()
        await mesure.vider()
        #expect(await enregistreur.lots.isEmpty)
    }
}

// MARK: - Les chemins du site, le corps envoyé

/// Un transport qui garde le corps envoyé, et répond 204.
private final class TransportEnregistreur: ClientTransport, @unchecked Sendable {
    var corps: Data?
    var operation: String?
    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws
        -> (HTTPResponse, HTTPBody?) {
        operation = operationID
        if let body { corps = try await Data(collecting: body, upTo: 16_384) }
        return (HTTPResponse(status: .noContent), nil)
    }
}

@MainActor
struct CheminsEtCorpsAudienceTests {
    @Test func lesCheminsSontCeuxDuSite() {
        #expect(CheminDuSite.affaire(123) == "/tickets/123")
        #expect(CheminDuSite.sondage(12) == "/sondages/12", "la route générée de la Communauté")
        #expect(CheminDuSite.onglet("telemetry", de: "/admin") == "/admin#telemetry")
        #expect(CheminDuSite.page("tableau-de-bord") == "/tableau-de-bord")
        #expect(CheminDuSite.page("inconnue") == nil)
    }

    @Test func leLotPorteLeCanalDeLAppEtRienDAutre() async throws {
        let transport = TransportEnregistreur()
        let service = ServiceAPI(transport: { _ in transport })
        try await service.envoyer(["/tickets/12", "/admin#telemetry"], a: ServiceSimule.residence)
        #expect(transport.operation == "post_telemetry_collect")
        let corps = try #require(transport.corps)
        let envoye = try #require(try JSONSerialization.jsonObject(with: corps) as? [String: Any])
        #expect(Set(envoye.keys) == ["canal", "events"], "ni appareil ni modèle")
        #expect(envoye["canal"] as? String == "ios")
        let evenements = try #require(envoye["events"] as? [[String: String]])
        #expect(evenements.map { $0["page"] } == ["/tickets/12", "/admin#telemetry"])
        #expect(evenements.allSatisfy { $0["action"] == MesureAudience.action })
        #expect(evenements.allSatisfy { Set($0.keys) == ["page", "action"] })
    }

    @Test func lesDeuxServicesRealisentLaMesure() async {
        let _: any ServiceAudience = ServiceAPI()
        let simule: any ServiceAudience = ServiceSimule(delai: .zero)
        // Le faux serveur refuse comme le vrai un lot hors de ses bornes.
        let tropDePages = Array(repeating: "/a", count: LimitesAudience.evenementsParLot + 1)
        await #expect(throws: ErreurService.self) { try await simule.envoyer(tropDePages, a: ServiceSimule.residence) }
    }
}
