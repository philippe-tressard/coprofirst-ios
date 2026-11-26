// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

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

/// La résidence des tests : celle de l'écran simulé (`LancementTVSimule`), une seule écriture.
func residenceDuHall() -> Installation { LancementTVSimule.residence }

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
