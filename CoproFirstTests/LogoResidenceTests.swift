// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
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
    #expect("1.9.0" > "1.15.0")
    #expect(try #require(VersionContrat("1.9.0")) < .logoSombre)
    #expect(try #require(VersionContrat("1.14.0")) < .logoSombre)
    #expect(try #require(VersionContrat("1.15.0")) >= .logoSombre)
    #expect(try #require(VersionContrat("1.15.1")) > .logoSombre)
    #expect(try #require(VersionContrat("1.100.0")) > .logoSombre)
    #expect(try #require(VersionContrat("2.0.0")) > .logoSombre)
    #expect(try #require(VersionContrat("0.99.99")) < .logoSombre)
}

// MARK: - La variante demandée

private func installation(logo: Bool = true, sombre: Bool? = true, contrat: String?) -> Installation {
    Installation(
        adresse: URL(string: "https://residence.exemple.fr")!, nom: "Résidence", aUnLogo: logo,
        versionContrat: contrat, aUnLogoSombre: sombre)
}

private let logoClair = "https://residence.exemple.fr/api/config/logo.png"
private let logoSombre = "https://residence.exemple.fr/api/config/logo.png?variante=sombre"

@Test func auSombreLaVarianteSeDemandeAPartirDu1_15_0() {
    #expect(installation(contrat: "1.15.0").adresseLogo(sombre: true)?.absoluteString == logoSombre)
    #expect(installation(contrat: "1.16.2").adresseLogo(sombre: true)?.absoluteString == logoSombre)
    #expect(installation(contrat: "2.0.0").adresseLogo(sombre: true)?.absoluteString == logoSombre)
}

@Test(arguments: ["1.14.0", "1.9.0", "1.12.0", "illisible", nil])
func avantLe1_15_0LeLogoResteCeluiDuClair(_ contrat: String?) {
    // Même adresse qu'au clair : le logo déjà lu sert, aucune requête de plus.
    let ancienne = installation(contrat: contrat)
    #expect(ancienne.adresseLogo(sombre: true)?.absoluteString == logoClair)
    #expect(ancienne.adresseLogo(sombre: true) == ancienne.adresseLogo(sombre: false))
}

@Test func sansVarianteTeleverseeLeLogoResteCeluiDuClair() {
    #expect(installation(sombre: false, contrat: "1.15.0").adresseLogo(sombre: true)?.absoluteString == logoClair)
    #expect(installation(sombre: nil, contrat: "1.15.0").adresseLogo(sombre: true)?.absoluteString == logoClair)
}

@Test func auClairEtSansLogoRienNeChange() {
    #expect(installation(contrat: "1.15.0").adresseLogo(sombre: false)?.absoluteString == logoClair)
    #expect(installation(logo: false, contrat: "1.15.0").adresseLogo(sombre: true) == nil)
    #expect(installation(logo: false, contrat: "1.15.0").adresseLogo(sombre: false) == nil)
}

// MARK: - Ce que sert GET /config

@Test func laConfigurationDitLeContratEtLaVarianteSombre() throws {
    let adresse = URL(string: "https://residence.exemple.fr")!
    let recente = try #require(
        Installation(
            adresse: adresse,
            config: [
                "site_nom": "Résidence", "site_logo": "logo-1.png", "site_logo_sombre": "logo-2.png",
                "version_contrat": "1.15.0",
            ]))
    #expect(recente.aUnLogo && recente.aUnLogoSombre == true)
    #expect(recente.contrat == .logoSombre)
    let ancienne = try #require(
        Installation(adresse: adresse, config: ["site_nom": "Résidence", "site_logo": "logo-1.png"]))
    #expect(ancienne.aUnLogoSombre == false && ancienne.versionContrat == nil)
    #expect(Installation(adresse: adresse, config: ["site_logo": "logo-1.png"]) == nil)
}

@Test func uneResidenceRetenueAvantLaVarianteSeRelitEncore() throws {
    // Une installation gardée par une version de l'app d'avant #70 n'a ni l'un ni l'autre.
    let json = #"{"adresse":"https://residence.exemple.fr","nom":"Résidence","aUnLogo":true}"#
    let relue = try JSONDecoder().decode(Installation.self, from: Data(json.utf8))
    #expect(relue.versionContrat == nil && relue.aUnLogoSombre == nil)
    #expect(relue.adresseLogo(sombre: true)?.absoluteString == logoClair)
}

// MARK: - Le cache distingue les deux variantes

/// Compte les lectures, et peut échouer.
private actor Lectures {
    var adresses: [URL] = []
    private var enEchec = false
    func lire(_ adresse: URL) throws -> Data {
        adresses.append(adresse)
        if enEchec { throw ErreurService.injoignable }
        let sombre = adresse.query()?.contains("variante=sombre") ?? false
        return ServiceSimule.logoDessine(sombre: sombre)
    }
    func echouer(_ oui: Bool) { enEchec = oui }
}

@MainActor
@Test func leCacheGardeLesDeuxVariantesCoteACote() async throws {
    let logos = LogosEnMemoire()
    let lectures = Lectures()
    let lire: @Sendable (URL) async throws -> Data = { try await lectures.lire($0) }
    let residence = installation(contrat: "1.15.0")
    let clair = try #require(residence.adresseLogo(sombre: false))
    let sombre = try #require(residence.adresseLogo(sombre: true))
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
@Test func uneInstallationAncienneNeLitQuUnLogo() async throws {
    let logos = LogosEnMemoire()
    let lectures = Lectures()
    let lire: @Sendable (URL) async throws -> Data = { try await lectures.lire($0) }
    let ancienne = installation(contrat: "1.14.0")
    for sombre in [false, true, false, true] {
        await logos.charger(try #require(ancienne.adresseLogo(sombre: sombre)), lire: lire)
    }
    #expect(await lectures.adresses.map(\.absoluteString) == [logoClair])
}

@MainActor
@Test func deuxDemandesSimultaneesNeLisentQuUneFois() async throws {
    let logos = LogosEnMemoire()
    let lectures = Lectures()
    let lire: @Sendable (URL) async throws -> Data = { try await lectures.lire($0) }
    let adresse = try #require(URL(string: logoSombre))
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
    let lire: @Sendable (URL) async throws -> Data = { try await lectures.lire($0) }
    let adresse = try #require(URL(string: logoClair))
    #expect(await logos.charger(adresse, lire: lire) == nil)
    #expect(logos.image(adresse) == nil)
    await lectures.echouer(false)
    #expect(await logos.charger(adresse, lire: lire) != nil)
    #expect(await lectures.adresses.count == 2)
}

// MARK: - Les deux services lisent le logo

@Test func lApiSimuleeSertLesDeuxDessins() async throws {
    let service = ServiceSimule(delai: .zero)
    let clair = try await service.logo(try #require(URL(string: logoClair)))
    let sombre = try await service.logo(try #require(URL(string: logoSombre)))
    #expect(UIImage(data: clair) != nil && UIImage(data: sombre) != nil)
    #expect(clair != sombre)
    let services: [any ServiceCoproFirst] = [ServiceAPI(), service]
    #expect(services.count == 2)
}
