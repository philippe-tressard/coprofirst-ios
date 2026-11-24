// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing
import UIKit

@testable import CoproFirst

// Le logo de la résidence et sa variante du fond sombre (#70).

// MARK: - La version du contrat se compare par ses nombres

@Test func uneVersionDeContratSeLitParSesNombres() {
    #expect(VersionContrat("1.15.0") == VersionContrat(1, 15, 0))
    #expect(VersionContrat("1.15") == VersionContrat(1, 15, 0))
    #expect(VersionContrat("2") == VersionContrat(2, 0, 0))
    #expect(VersionContrat(" 1.14.0 ") == VersionContrat(1, 14, 0))
    #expect(VersionContrat("1.15.0")?.description == "1.15.0")
}

@Test(arguments: [nil, "", "1.x.0", "v1.15.0", "1..0", "1.15.0.1", "-1.15.0", "+1.15.0", "1.15.0-beta", "١.١٥.٠"])
func uneVersionIllisibleNeSeDevinePas(_ texte: String?) {
    #expect(VersionContrat(texte) == nil)
}

@Test func lesVersionsSeComparentParNombresJamaisParCaracteres() throws {
    // L'ordre des caractères mettrait « 1.9.0 » après « 1.15.0 » : les nombres, non.
    let reference = VersionContrat(1, 15, 0)
    #expect("1.9.0" > "1.15.0")
    #expect(try #require(VersionContrat("1.9.0")) < reference)
    #expect(try #require(VersionContrat("1.14.0")) < reference)
    #expect(try #require(VersionContrat("1.15.0")) >= reference)
    #expect(try #require(VersionContrat("1.15.1")) > reference)
    #expect(try #require(VersionContrat("1.100.0")) > reference)
    #expect(try #require(VersionContrat("2.0.0")) > reference)
    #expect(try #require(VersionContrat("0.99.99")) < reference)
}

// MARK: - La variante demandée

private func installation(logo: Bool = true, sombre: Bool? = true, contrat: String?) -> Installation {
    Installation(
        adresse: URL(string: "https://residence.example.com")!, nom: "Résidence", aUnLogo: logo,
        versionContrat: contrat, aUnLogoSombre: sombre)
}

private let residenceTest = URL(string: "https://residence.example.com")!
private let logoClair = LogoDemande(installation: residenceTest, sombre: false)
private let logoSombre = LogoDemande(installation: residenceTest, sombre: true)

/// Le plancher sert la variante (contrat 1.15.0) : seule la variante TÉLÉVERSÉE décide,
/// plus la version — une version illisible ne prive plus le fond sombre de son logo (#254).
@Test(arguments: ["1.15.0", "2.0.0", VersionContrat.plancher.description, "illisible", nil] as [String?])
func auSombreLaVarianteTeleverseeSeDemande(_ contrat: String?) {
    #expect(installation(contrat: contrat).logo(sombre: true) == logoSombre)
}

@Test func sansVarianteTeleverseeLeLogoResteCeluiDuClair() {
    #expect(installation(sombre: false, contrat: "1.15.0").logo(sombre: true) == logoClair)
    #expect(installation(sombre: nil, contrat: "1.15.0").logo(sombre: true) == logoClair)
}

@Test func auClairEtSansLogoRienNeChange() {
    #expect(installation(contrat: "1.15.0").logo(sombre: false) == logoClair)
    #expect(installation(logo: false, contrat: "1.15.0").logo(sombre: true) == nil)
    #expect(installation(logo: false, contrat: "1.15.0").logo(sombre: false) == nil)
}

// MARK: - Ce que sert GET /config

@Test func laConfigurationDitLeContratEtLaVarianteSombre() throws {
    let adresse = URL(string: "https://residence.example.com")!
    let recente = try #require(
        Installation(
            adresse: adresse,
            config: [
                "site_nom": "Résidence", "site_logo": "logo-1.png", "site_logo_sombre": "logo-2.png",
                "version_contrat": "1.15.0",
            ]))
    #expect(recente.aUnLogo && recente.aUnLogoSombre == true)
    #expect(recente.contrat == VersionContrat(1, 15, 0))
    let ancienne = try #require(
        Installation(adresse: adresse, config: ["site_nom": "Résidence", "site_logo": "logo-1.png"]))
    #expect(ancienne.aUnLogoSombre == false && ancienne.versionContrat == nil)
    #expect(Installation(adresse: adresse, config: ["site_logo": "logo-1.png"]) == nil)
}

@Test func uneResidenceRetenueAvantLaVarianteSeRelitEncore() throws {
    // Une installation gardée par une version de l'app d'avant #70 n'a ni l'un ni l'autre.
    let json = #"{"adresse":"https://residence.example.com","nom":"Résidence","aUnLogo":true}"#
    let relue = try JSONDecoder().decode(Installation.self, from: Data(json.utf8))
    #expect(relue.versionContrat == nil && relue.aUnLogoSombre == nil)
    #expect(relue.logo(sombre: true) == logoClair)
}

// MARK: - Le cache distingue les deux variantes

/// Compte les lectures, et peut échouer.
private actor Lectures {
    var adresses: [LogoDemande] = []
    private var enEchec = false
    func lire(_ demande: LogoDemande) throws -> Data {
        adresses.append(demande)
        if enEchec { throw ErreurService.injoignable }
        return ServiceSimule.logoDessine(sombre: demande.sombre)
    }
    func echouer(_ oui: Bool) { enEchec = oui }
}

@MainActor
@Test func leCacheGardeLesDeuxVariantesCoteACote() async throws {
    let logos = LogosEnMemoire()
    let lectures = Lectures()
    let lire: @Sendable (LogoDemande) async throws -> Data = { try await lectures.lire($0) }
    let residence = installation(contrat: "1.15.0")
    let clair = try #require(residence.logo(sombre: false))
    let sombre = try #require(residence.logo(sombre: true))
    #expect(clair != sombre)

    let imageClaire = await logos.charger(clair, lire: lire)
    let imageSombre = await logos.charger(sombre, lire: lire)
    #expect(imageClaire != nil && imageSombre != nil)
    #expect(imageClaire?.pngData() != imageSombre?.pngData())
    // Revenir au clair, puis au sombre : rien n'est relu.
    #expect(await logos.charger(clair, lire: lire) === imageClaire)
    #expect(await logos.charger(sombre, lire: lire) === imageSombre)
    #expect(await lectures.adresses == [clair, sombre])
    #expect(logos.image(clair) === imageClaire && logos.image(sombre) === imageSombre)
}

@MainActor
@Test func sansVarianteTeleverseeUnSeulLogoSeLit() async throws {
    // La porte de version retirée (#254), c'est la variante TÉLÉVERSÉE qui décide : sans
    // elle, clair et sombre partagent une adresse, donc une lecture.
    let logos = LogosEnMemoire()
    let lectures = Lectures()
    let lire: @Sendable (LogoDemande) async throws -> Data = { try await lectures.lire($0) }
    let ancienne = installation(sombre: false, contrat: VersionContrat.plancher.description)
    for sombre in [false, true, false, true] {
        await logos.charger(try #require(ancienne.logo(sombre: sombre)), lire: lire)
    }
    #expect(await lectures.adresses == [logoClair])
}

@MainActor
@Test func deuxDemandesSimultaneesNeLisentQuUneFois() async throws {
    let logos = LogosEnMemoire()
    let lectures = Lectures()
    let lire: @Sendable (LogoDemande) async throws -> Data = { try await lectures.lire($0) }
    let adresse = logoSombre
    async let premiere = logos.charger(adresse, lire: lire)
    async let seconde = logos.charger(adresse, lire: lire)
    let (une, autre) = await (premiere, seconde)
    #expect(une != nil && une === autre)
    #expect(await lectures.adresses.count == 1)
}

@MainActor
@Test func unEchecNeSeGardePas() async throws {
    let logos = LogosEnMemoire()
    let lectures = Lectures()
    await lectures.echouer(true)
    let lire: @Sendable (LogoDemande) async throws -> Data = { try await lectures.lire($0) }
    let adresse = logoClair
    #expect(await logos.charger(adresse, lire: lire) == nil)
    #expect(logos.image(adresse) == nil)
    await lectures.echouer(false)
    #expect(await logos.charger(adresse, lire: lire) != nil)
    #expect(await lectures.adresses.count == 2)
}

// MARK: - Les deux services lisent le logo

/// Un serveur qui sert une IMAGE à GET /config/logo.png, et note les requêtes reçues.
private actor RequetesLogo {
    var recues: [String] = []
    func noter(_ chemin: String) { recues.append(chemin) }
}

private struct TransportLogo: ClientTransport {
    let requetes: RequetesLogo
    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws
        -> (HTTPResponse, HTTPBody?) {
        await requetes.noter("\(operationID) \(request.path ?? "")")
        var reponse = HTTPResponse(status: .ok)
        reponse.headerFields[.contentType] = "image/png"
        return (reponse, HTTPBody(ServiceSimule.logoDessine(sombre: request.path?.contains("sombre") ?? false)))
    }
}

/// Le logo passe par la route GÉNÉRÉE (#345) : l'image servie se lit malgré le JSON que
/// déclare le contrat, la variante part en paramètre — et seulement pour le sombre.
@Test func lApiLitLeLogoParLaRouteGeneree() async throws {
    let requetes = RequetesLogo()
    let service = ServiceAPI(transport: { _ in TransportLogo(requetes: requetes) })
    let clair = try await service.logo(logoClair)
    let sombre = try await service.logo(logoSombre)
    #expect(UIImage(data: clair) != nil && UIImage(data: sombre) != nil && clair != sombre)
    let attendues = [
        "\(Operations.GetConfigLogoPng.id) /api/config/logo.png",
        "\(Operations.GetConfigLogoPng.id) /api/config/logo.png?variante=sombre",
    ]
    #expect(await requetes.recues == attendues)
}

@Test func lApiSimuleeSertLesDeuxDessins() async throws {
    let service = ServiceSimule(delai: .zero)
    let clair = try await service.logo(logoClair)
    let sombre = try await service.logo(logoSombre)
    #expect(UIImage(data: clair) != nil && UIImage(data: sombre) != nil)
    #expect(clair != sombre)
    let services: [any ServiceCoproFirst] = [ServiceAPI(), service]
    #expect(services.count == 2)
}
