// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

// La liaison de l'iPhone à l'Apple Watch (#226) : un jeton de montre émis ou renouvelé à
// l'ouverture d'une résidence, retiré à sa fermeture ; l'iPhone n'en garde que l'identifiant.

@Test func laLiaisonResteEteinteJusquAuGesteDePhilippe() {
    #expect(!LiaisonMontre.active, "allumée avec Wear OS, sur le geste de Philippe (#207)")
}

@Test func lesDeuxServicesRealisentLesMontres() {
    let _: any ServiceMontres = ServiceAPI()
    let _: any ServiceMontres = ServiceSimule()
}

/// Une app neuve : la résidence inventée, une montre jointe ou non, la liaison abonnée.
@MainActor
private struct AppAvecMontre {
    let parcours: Parcours
    let service = ServiceSimule(delai: .zero)
    let canal: CanalSimule
    let liaison: LiaisonsMontre
    let suite = UserDefaults(suiteName: "montre-tests-\(UUID().uuidString)") ?? .standard

    init(jointe: Bool = true, active: Bool = true) async {
        parcours = Parcours(service: service, connues: InstallationsConnues(reglages: suite))
        let canal = CanalSimule(jointe: jointe)
        self.canal = canal
        liaison = LiaisonsMontre(
            canal: { canal }, service: service, gardees: MontresGardees(reglages: suite), active: active)
        await parcours.abonner(liaison)
    }

    var residence: Installation { ServiceSimule.residence }
}

@MainActor
@Test func aLOuvertureLaMontreRecoitUnJetonEtLIPhoneNeGardeQueSonIdentifiant() async throws {
    let app = await AppAvecMontre()
    await app.liaison.residenceOuverte(app.residence)
    let id = try #require(app.liaison.gardees.id(pour: app.residence))
    #expect(app.service.montresReliees(app.residence) == [id])
    guard case .liaison(let adresse, let nom, let jeton, _) = try #require(app.canal.transmis.last) else {
        Issue.record("la montre n'a pas reçu de liaison : \(app.canal.transmis)")
        return
    }
    #expect(adresse == app.residence.adresse)
    #expect(nom == app.residence.nom)
    #expect(!jeton.enClair.isEmpty)
    let gardees = app.suite.dictionaryRepresentation().values.map { "\($0)" }
    #expect(gardees.contains("\(id)"), "l'identifiant se garde")
    #expect(!gardees.contains { $0.contains(jeton.enClair) }, "le jeton ne se garde pas sur l'iPhone")
}

@MainActor
@Test func uneSecondeOuvertureRenouvelleLaMemeMontre() async throws {
    let app = await AppAvecMontre()
    await app.liaison.residenceOuverte(app.residence)
    let id = try #require(app.liaison.gardees.id(pour: app.residence))
    await app.liaison.residenceOuverte(app.residence)
    #expect(app.liaison.gardees.id(pour: app.residence) == id)
    #expect(app.service.montresReliees(app.residence) == [id], "pas une montre de plus")
    #expect(app.canal.transmis.count == 2)
}

@MainActor
@Test func uneMontreQueLeServeurNeConnaitPlusEstEmiseANeuf() async throws {
    let app = await AppAvecMontre()
    await app.liaison.residenceOuverte(app.residence)
    let ancienne = try #require(app.liaison.gardees.id(pour: app.residence))
    try await app.service.retirerMontre(ancienne, dans: app.residence)
    await app.liaison.residenceOuverte(app.residence)
    let neuve = try #require(app.liaison.gardees.id(pour: app.residence))
    #expect(neuve != ancienne)
    #expect(app.service.montresReliees(app.residence) == [neuve])
}

@MainActor
@Test func aLaDeconnexionLaMontreSeRetireEtSEfface() async throws {
    let app = await AppAvecMontre()
    await app.liaison.residenceOuverte(app.residence)
    await app.parcours.deconnecter(app.residence)
    #expect(app.service.montresReliees(app.residence).isEmpty, "le jeton cesse de servir")
    #expect(app.liaison.gardees.id(pour: app.residence) == nil)
    #expect(app.canal.transmis.last == .effacement(adresse: app.residence.adresse))
}

@MainActor
@Test func sansMontreJointeOuLiaisonEteinteRienNePart() async {
    for app in [await AppAvecMontre(jointe: false), await AppAvecMontre(active: false)] {
        await app.liaison.residenceOuverte(app.residence)
        await app.liaison.residenceFermee(app.residence)
        #expect(app.service.montresReliees(app.residence).isEmpty)
        #expect(app.canal.transmis.isEmpty)
    }
}

@MainActor
@Test func unAbonneNeSInscritQuUneFoisEtLOuvertureLePrevient() async {
    let app = await AppAvecMontre()
    await app.parcours.abonner(app.liaison)
    #expect(app.parcours.abonnes.liste.count == 1)
    app.parcours.ouvrir(app.residence)
    for _ in 0..<200 where app.canal.transmis.isEmpty { try? await Task.sleep(for: .milliseconds(10)) }
    #expect(app.canal.transmis.count == 1, "l'ouverture prévient la liaison")
}

@Test func leHandoffDeLaMontreOuvreLaClocheDeSaResidence() {
    let adresse = ServiceSimule.residence.adresse
    let destination = Destination.clocheDeLaMontre(ClocheSurLiPhone.userInfo(adresse))
    #expect(destination?.ecran == .notifications)
    #expect(destination?.adresse.host() == adresse.host())
    #expect(Destination.clocheDeLaMontre(["adresse": "http://ailleurs.test"]) == nil)
}

@Test func leJetonDeMontreNeSEcritJamais() {
    let jeton = JetonDeMontre(id: 3, jeton: "brut-secret-456", expireLe: .now)
    var vidage = ""
    dump(jeton, to: &vidage)
    for texte in ["\(jeton)", String(reflecting: jeton), vidage] {
        #expect(!texte.contains("brut-secret"), "le jeton paraît dans « \(texte.prefix(60))… »")
    }
}
