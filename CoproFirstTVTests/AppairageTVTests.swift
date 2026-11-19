// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// Un serveur d'écran simulé : les réponses d'interrogation se servent dans l'ordre, les
/// affiches et les images se règlent par test. Aucun réseau.
actor ServeurEcranSimule: ServiceEcranTV {
    var demande: Result<DemandeAppairageTV, ErreurService> = .success(
        DemandeAppairageTV(codeAppareil: "secret", codeCourt: "BCDF-GHJK", expireDans: 600, intervalle: 5))
    var interrogations: [ReponseAppairage] = []
    private(set) var interrogees = 0
    var lecture: Result<[AfficheHall], ErreurService> = .success([])
    private(set) var lectures = 0
    private(set) var jetonsPresentes: [String] = []
    var imagesEnEchec: Set<Int> = []

    func regler(interrogations: [ReponseAppairage]) { self.interrogations = interrogations }
    func regler(demande: Result<DemandeAppairageTV, ErreurService>) { self.demande = demande }
    func regler(lecture: Result<[AfficheHall], ErreurService>) { self.lecture = lecture }
    func regler(imagesEnEchec: Set<Int>) { self.imagesEnEchec = imagesEnEchec }

    func demander(_ adresse: URL) async throws -> DemandeAppairageTV { try demande.get() }

    func interroger(_ codeAppareil: String, _ adresse: URL) async throws -> ReponseAppairage {
        interrogees += 1
        return interrogations.isEmpty ? .enAttente : interrogations.removeFirst()
    }

    func affiches(_ adresse: URL, jeton: String) async throws -> [AfficheHall] {
        lectures += 1
        jetonsPresentes.append(jeton)
        return try lecture.get()
    }

    func image(_ affiche: Int, rang: Int, _ adresse: URL, jeton: String) async throws -> Data {
        if imagesEnEchec.contains(rang) { throw ErreurService.injoignable }
        return Data([UInt8(affiche), UInt8(rang)])
    }
}

/// Une horloge que le test avance : chaque attente la fait avancer de sa durée, sans dormir.
final class HorlogeSimulee: @unchecked Sendable {
    private let verrou = NSLock()
    private var instant = Date(timeIntervalSince1970: 1_800_000_000)
    private(set) var attentes: [Duration] = []

    var maintenant: Date { verrou.withLock { instant } }

    func attendre(_ duree: Duration) {
        verrou.withLock {
            attentes.append(duree)
            instant += TimeInterval(duree.components.seconds)
        }
    }
}

func residenceDuHall() -> Installation {
    Installation(
        adresse: URL(string: "https://tilleuls.example.com")!, nom: "Les Tilleuls", aUnLogo: false,
        codePalette: "prune", versionContrat: VersionContrat.plancher.description)
}

@MainActor
private func appairage(_ serveur: ServeurEcranSimule, _ horloge: HorlogeSimulee) -> AppairageTV {
    AppairageTV(
        residence: residenceDuHall(), service: serveur, attendre: { horloge.attendre($0) },
        maintenant: { horloge.maintenant })
}

/// Le code s'affiche, l'écran interroge à l'intervalle imposé, et le jeton arrive dès que
/// le conseil confirme (#218, lot 3 ; RFC 8628).
@MainActor
@Test func leCodeSAfficheEtLeJetonArriveALaConfirmation() async {
    let serveur = ServeurEcranSimule()
    await serveur.regler(interrogations: [.enAttente, .enAttente, .jeton("jeton-1", expireLe: .now)])
    let horloge = HorlogeSimulee()
    let modele = appairage(serveur, horloge)
    let jeton = await modele.suivre()
    #expect(jeton == "jeton-1")
    #expect(await serveur.interrogees == 3)
    #expect(horloge.attentes == [.seconds(5), .seconds(5), .seconds(5)], "à l'intervalle imposé")
    guard case .code(let code, _) = modele.etat else {
        Issue.record("le code reste affiché jusqu'au jeton : \(modele.etat)")
        return
    }
    #expect(code == "BCDF-GHJK")
}

/// « ralentir » : l'intervalle grandit de cinq secondes, comme le serveur l'a fait grandir.
@MainActor
@Test func ralentirAllongeLIntervalle() async {
    let serveur = ServeurEcranSimule()
    await serveur.regler(interrogations: [.ralentir, .ralentir, .jeton("j", expireLe: .now)])
    let horloge = HorlogeSimulee()
    _ = await appairage(serveur, horloge).suivre()
    #expect(horloge.attentes == [.seconds(5), .seconds(10), .seconds(15)])
}

/// Le code échu ne se renouvelle pas seul : l'écran le dit, et n'interroge plus.
@MainActor
@Test func unCodeEchuSArreteEtLeDit() async {
    let serveur = ServeurEcranSimule()
    await serveur.regler(demande: .success(
        DemandeAppairageTV(codeAppareil: "s", codeCourt: "BCDF-GHJK", expireDans: 12, intervalle: 5)))
    let horloge = HorlogeSimulee()
    let modele = appairage(serveur, horloge)
    #expect(await modele.suivre() == nil)
    #expect(modele.etat == .expire)
    #expect(await serveur.interrogees == 2, "à 5 s et 10 s ; à 15 s, le code a expiré")
}

@MainActor
@Test func unCodeInconnuDuServeurSArreteAussi() async {
    let serveur = ServeurEcranSimule()
    await serveur.regler(interrogations: [.inconnu])
    let modele = appairage(serveur, HorlogeSimulee())
    #expect(await modele.suivre() == nil)
    #expect(modele.etat == .expire)
}

/// La demande refusée (429 : trop d'appairages en attente) dit la phrase du serveur.
@MainActor
@Test func uneDemandeRefuseeDitLaPhraseDuServeur() async {
    let serveur = ServeurEcranSimule()
    let refus = ErreurService.refus(.init(phrase: "Trop d'appairages en attente — réessayez dans quelques minutes."))
    await serveur.regler(demande: .failure(refus))
    let modele = appairage(serveur, HorlogeSimulee())
    #expect(await modele.suivre() == nil)
    #expect(modele.etat == .echec(refus))
}

/// Le `detail` d'un refus 400 se lit tel que le serveur l'écrit (`appairage_ecran`).
@Test func leDetailDUnRefusDitLaSuite() {
    #expect(ReponseAppairage.depuis(detail: "en_attente") == .enAttente)
    #expect(ReponseAppairage.depuis(detail: "ralentir") == .ralentir)
    #expect(ReponseAppairage.depuis(detail: "inconnu") == .inconnu)
    #expect(ReponseAppairage.depuis(detail: "Autre chose") == nil)
    #expect(ReponseAppairage.depuis(detail: nil) == nil)
}
