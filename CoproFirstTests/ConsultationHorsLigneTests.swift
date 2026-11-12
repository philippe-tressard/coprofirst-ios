// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import CoproFirst

// La consultation hors ligne par le service réel (#101) : ce que le serveur a servi en
// ligne se relit sans réseau, par la porte du client — et rien ne part. Se déconnecter,
// une session refusée : tout s'efface. Aucune requête ne sort : un serveur de test.

/// Le secret que le serveur de test pose en cookie : il ne doit jamais atteindre le disque.
private let secret = "SECRET-DU-TEST"

/// Un serveur qu'on peut couper du réseau, et dont la session peut être refusée.
private actor ServeurDeTest {
    private(set) var recues: [String] = []
    private var enLigne = true
    private var refreshAccepte = true
    private var statutDesLectures = HTTPResponse.Status.ok
    private var titre = "Coupure d'eau jeudi"

    func couper() { enLigne = false }
    func retablir() { enLigne = true }
    func refuserLaSession() { refreshAccepte = false }
    func servir(_ statut: HTTPResponse.Status) { statutDesLectures = statut }
    func publier(_ nouveau: String) { titre = nouveau }

    func repondre(_ operation: String) throws -> (HTTPResponse.Status, String, String) {
        guard enLigne else { throw URLError(.notConnectedToInternet) }
        recues.append(operation)
        switch operation {
        case Operations.PostAuthRefresh.id:
            return refreshAccepte ? (.ok, "application/json", "{}") : Self.refus
        case Operations.PostAuthLogout.id:
            return (.ok, "application/json", "{}")
        case Operations.GetDocumentsDocIdTélécharger.id:
            return (statutDesLectures, "application/pdf", "%PDF-1.7 procès-verbal")
        case Operations.GetFlux.id:
            let fil =
                #"{"delai_recent_jours": 7, "items": [{"type": "actualite", "id": "12", "#
                + #""date": "2026-11-10T13:32:00Z", "titre": "\#(titre)"}]}"#
            return statutDesLectures == .ok ? (.ok, "application/json", fil) : (statutDesLectures, "application/json", "{}")
        default:
            return (statutDesLectures, "application/json", "{}")
        }
    }

    private static let refus = (HTTPResponse.Status.unauthorized, "application/json", #"{"detail": "refusé"}"#)
}

private struct TransportDeTest: ClientTransport {
    let serveur: ServeurDeTest

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws
        -> (HTTPResponse, HTTPBody?) {
        let (statut, type, corps) = try await serveur.repondre(operationID)
        var reponse = HTTPResponse(status: statut)
        reponse.headerFields[.contentType] = type
        reponse.headerFields[.setCookie] = "refresh_token=\(secret); HttpOnly; Secure"
        return (reponse, HTTPBody(corps))
    }
}

private let residence = Installation(
    adresse: URL(string: "https://lecture-gardee.exemple")!, nom: "Résidence", aUnLogo: false)

/// Le service réel sur le serveur de test, avec un magasin jetable.
private struct Banc {
    let disque = MagasinDeTest()
    let serveur = ServeurDeTest()
    let magasin: LecturesGardees
    let service: ServiceAPI

    init(sessionGardee: Bool = true) {
        let serveur = serveur
        magasin = disque.magasin(sessionGardee: sessionGardee)
        service = ServiceAPI(transport: { _ in TransportDeTest(serveur: serveur) }, lectures: magasin)
    }
}

@Suite struct ConsultationHorsLigneTests {
    @Test func lesDeuxServicesPortentLaConsultation() {
        let _: any ServiceHorsLigne = ServiceAPI()
        let _: any ServiceHorsLigne = ServiceSimule()
    }

    @Test func ceQuiAEteLuEnLigneSeRelitSansReseauEtRienNePart() async throws {
        let banc = Banc()
        defer { banc.disque.nettoyer() }
        let enLigne = try await banc.service.fil(residence)
        #expect(enLigne.map(\.titre) == ["Coupure d'eau jeudi"])

        await banc.serveur.couper()
        #expect(banc.service.consulterHorsLigne(residence) == .gardee(banc.disque.horloge.maintenant))
        let avant = await banc.serveur.recues
        #expect(try await banc.service.fil(residence) == enLigne, "le fil, tel que le serveur l'avait servi")
        #expect(await banc.serveur.recues == avant, "aucune requête n'est partie")
    }

    @Test func enConsultationAucunGesteNiAucuneAutreLectureNePart() async throws {
        let banc = Banc()
        defer { banc.disque.nettoyer() }
        _ = try await banc.service.fil(residence)
        _ = banc.service.consulterHorsLigne(residence)
        // Le réseau est là, mais la session n'est pas reprise : rien ne doit sortir.
        let avant = await banc.serveur.recues
        await #expect(throws: ErreurService.horsLigne) {
            try await banc.service.repondre("Bonjour", a: 41, dans: residence)
        }
        await #expect(throws: ErreurService.horsLigne, "une lecture qui n'a jamais été gardée") {
            try await banc.service.annuaire(residence)
        }
        #expect(await banc.serveur.recues == avant, "refusé à la porte, avant de partir")
    }

    @Test func sansLectureGardeeRienNeSOuvre() async {
        let banc = Banc()
        defer { banc.disque.nettoyer() }
        #expect(banc.service.consulterHorsLigne(residence) == .aucune)
        #expect(!banc.magasin.enConsultation(residence.hote))
    }

    @Test func sansSessionGardeeAuTrousseauRienNEstEcrit() async throws {
        let banc = Banc(sessionGardee: false)
        defer { banc.disque.nettoyer() }
        _ = try await banc.service.fil(residence)
        #expect(banc.disque.fichiers.isEmpty)
    }

    // MARK: - Effacer

    @Test func seDeconnecterEffaceLaLectureGardee() async throws {
        let banc = Banc()
        defer { banc.disque.nettoyer() }
        _ = try await banc.service.fil(residence)
        #expect(!banc.disque.fichiers.isEmpty)

        _ = await banc.service.deconnecter(residence)
        #expect(banc.disque.fichiers.isEmpty, "plus rien sur le disque")
        #expect(banc.service.consulterHorsLigne(residence) == .aucune, "plus rien de lisible sans réseau")
    }

    @Test func seDeconnecterSansReseauEffaceAussi() async throws {
        let banc = Banc()
        defer { banc.disque.nettoyer() }
        _ = try await banc.service.fil(residence)
        await banc.serveur.couper()
        _ = banc.service.consulterHorsLigne(residence)

        #expect(await banc.service.deconnecter(residence) == false, "le serveur n'a pas pu être joint")
        #expect(banc.disque.fichiers.isEmpty)
        #expect(!banc.magasin.enConsultation(residence.hote))
    }

    @Test func uneSessionRefuseeALaRepriseEffaceLeJetonEtLaLecture() async throws {
        let banc = Banc()
        defer { banc.disque.nettoyer() }
        _ = try await banc.service.fil(residence)
        // Le Trousseau du simulateur, sans code ni biométrie : lu sans invite. Sous une
        // autre protection, ce test ne pourrait pas s'exécuter — il échoue, il ne passe pas.
        let protection = Trousseau.enregistrer("jeton-de-test", pour: residence.hote)
        defer { Trousseau.supprimer(pour: residence.hote) }
        try #require(protection == .aucune)
        await banc.serveur.refuserLaSession()

        await #expect(throws: ErreurService.sessionExpiree) { try await banc.service.reprendre(residence) }
        #expect(!Trousseau.contient(pour: residence.hote), "le jeton")
        #expect(banc.disque.fichiers.isEmpty, "et la lecture, par la même porte")
    }

    @Test func unRefusAuRetourDuReseauEffaceTout() async throws {
        let banc = Banc()
        defer { banc.disque.nettoyer() }
        _ = try await banc.service.fil(residence)
        _ = banc.service.consulterHorsLigne(residence)
        await banc.serveur.refuserLaSession()

        await #expect(throws: ErreurService.sessionExpiree) { try await banc.service.reprendreEnLigne(residence) }
        #expect(banc.disque.fichiers.isEmpty)
        #expect(!banc.magasin.enConsultation(residence.hote))
    }

    @Test func unRefusDeSessionEnLigneEffaceLaLecture() async throws {
        let banc = Banc()
        defer { banc.disque.nettoyer() }
        _ = try await banc.service.fil(residence)
        await banc.serveur.refuserLaSession()
        await banc.serveur.servir(.unauthorized)

        await #expect(throws: ErreurService.sessionExpiree) { try await banc.service.fil(residence) }
        #expect(banc.disque.fichiers.isEmpty, "un compte révoqué ne garde rien")
    }

    @Test func uneLectureDevenueInterditeSeRetire() async throws {
        let banc = Banc()
        defer { banc.disque.nettoyer() }
        _ = try await banc.service.fil(residence)
        await banc.serveur.servir(.forbidden)
        await #expect(throws: (any Error).self) { try await banc.service.fil(residence) }
        #expect(banc.disque.fichiers.isEmpty)
    }

    // MARK: - Le retour du réseau

    @Test func laSessionRepriseRefermeLaConsultationEtToutSeRelit() async throws {
        let banc = Banc()
        defer { banc.disque.nettoyer() }
        _ = try await banc.service.fil(residence)
        await banc.serveur.couper()
        _ = banc.service.consulterHorsLigne(residence)
        await #expect(throws: ErreurService.horsLigne, "toujours sans réseau : la consultation continue") {
            try await banc.service.reprendreEnLigne(residence)
        }
        #expect(banc.magasin.enConsultation(residence.hote))

        await banc.serveur.retablir()
        await banc.serveur.publier("Eau rétablie")
        try await banc.service.reprendreEnLigne(residence)
        #expect(!banc.magasin.enConsultation(residence.hote))
        #expect(try await banc.service.fil(residence).map(\.titre) == ["Eau rétablie"], "relu du serveur")
    }

    // MARK: - Ce qui est gardé, et rien d'autre

    @Test func rienDeLAdministrationNiDeLEspaceCSNEstGarde() async {
        let banc = Banc()
        defer { banc.disque.nettoyer() }
        let client = banc.service.client(residence.adresse)
        // La réponse du serveur de test ne se décode pas : seule compte la porte.
        _ = try? await client.getAdminUtilisateurs()
        _ = try? await client.getAdminAnnuaireCs()
        _ = try? await client.getNotifications()
        #expect(await banc.serveur.recues.count == 3, "les trois lectures sont parties")
        #expect(banc.disque.fichiers.isEmpty, "aucune n'a été écrite")
    }

    @Test func laListeBlancheNeGardeQueDesLecturesHorsAdministration() {
        let gardees = LectureGardee.operations
        #expect(gardees.allSatisfy { $0.hasPrefix("get_") }, "des lectures, jamais un geste")
        #expect(Set(gardees.filter { $0.contains("admin") }) == LectureGardee.sousAdmin)
        #expect(LectureGardee.sousAdmin == [Operations.GetAdminAnnuaire.id], "l'annuaire de tous les résidents")
        #expect(gardees.allSatisfy { !$0.hasSuffix("_cs") && !$0.contains("_cs_") }, "rien de l'Espace CS")
        #expect(!gardees.contains(Operations.GetNotifications.id))
        #expect(LectureGardee.horsConsultation.isDisjoint(with: gardees))
    }

    @Test func niJetonNiCookieNAtteintLeDisque() async throws {
        let banc = Banc()
        defer { banc.disque.nettoyer() }
        _ = try await banc.service.fil(residence)
        let fichiers = banc.disque.fichiers
        #expect(!fichiers.isEmpty)
        for fichier in fichiers {
            let octets = try Data(contentsOf: fichier)
            #expect(octets.range(of: Data(secret.utf8)) == nil, "le cookie du serveur")
            #expect(octets.range(of: Data("refresh_token".utf8)) == nil)
        }
    }

    @Test func unDocumentDejaOuvertSeRouvreSansReseau() async throws {
        let banc = Banc()
        defer { banc.disque.nettoyer() }
        let enLigne = try await banc.service.document(7, nom: "pv-lecture-gardee.pdf", dans: residence)
        defer { try? FileManager.default.removeItem(at: enLigne) }
        let servi = try Data(contentsOf: enLigne)
        try FileManager.default.removeItem(at: enLigne)

        await banc.serveur.couper()
        _ = banc.service.consulterHorsLigne(residence)
        let horsLigne = try await banc.service.document(7, nom: "pv-lecture-gardee.pdf", dans: residence)
        #expect(try Data(contentsOf: horsLigne) == servi)
        await #expect(throws: ErreurService.horsLigne, "un document jamais ouvert") {
            try await banc.service.document(8, nom: nil, dans: residence)
        }
    }

    @Test func unePhotoDejaOuverteSeRouvreSansReseau() async throws {
        let banc = Banc()
        defer { banc.disque.nettoyer() }
        let photo = Data([0xFF, 0xD8, 0xFF])
        banc.magasin.garder(photo, type: nil, cle: LectureGardee.clePhoto("/uploads/a.jpg"), de: residence.hote)
        _ = banc.service.consulterHorsLigne(residence)
        #expect(try await banc.service.photoConsultable("/uploads/a.jpg", dans: residence) == photo)
        await #expect(throws: ErreurService.horsLigne) {
            try await banc.service.photoConsultable("/uploads/b.jpg", dans: residence)
        }
    }
}
