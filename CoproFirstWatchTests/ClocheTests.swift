// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// Comment la montre range la cloche (#226) : non lues d'abord, urgentes devant, l'ordre du
/// serveur gardé dans chaque groupe ; puis les déjà lues.
struct ClocheTests {
    private func alerte(_ id: Int, lue: Bool = false, urgente: Bool = false) -> NotificationRecue {
        NotificationRecue(
            id: id, type: "ticket", titre: "Alerte \(id)", corps: "<p>Texte</p>", lue: lue, urgente: urgente,
            creeLe: Date(timeIntervalSince1970: 1_800_000_000 - Double(id) * 60))
    }

    @Test func lesUrgentesPassentDevantSansDefaireLOrdreDuServeur() {
        let cloche = Cloche([
            alerte(1), alerte(2, urgente: true), alerte(3, lue: true), alerte(4), alerte(5, urgente: true),
        ])
        #expect(cloche.nonLues.map(\.id) == [2, 5, 1, 4])
        #expect(cloche.lues.map(\.id) == [3])
        #expect(cloche.urgentes == 2)
    }

    @Test func uneUrgenteDejaLueResteAvecLesLues() {
        let cloche = Cloche([alerte(1, lue: true, urgente: true), alerte(2)])
        #expect(cloche.nonLues.map(\.id) == [2])
        #expect(cloche.lues.map(\.id) == [1])
        #expect(cloche.urgentes == 0)
    }

    @Test func uneClocheSansAlerteEstVide() {
        #expect(Cloche([]).vide)
        #expect(!Cloche([alerte(1, lue: true)]).vide)
        #expect(Cloche([alerte(7)]).alerte(7)?.titre == "Alerte 7")
        #expect(Cloche([alerte(7)]).alerte(8) == nil)
    }

    @Test func laLiaisonEteinteNeReliePas() {
        #expect(!LiaisonMontre.active)
        #expect(EtatMontre.auLancement([]) == .nonReliee)
    }

    @Test func lApiSimuleeRelieAUneResidenceInventee() {
        #expect(
            EtatMontre.auLancement(["-api-simulee"])
                == .reliee(residence: ClocheSimulee.residence, source: .simulee(.boite(nombre: nil))))
        #expect(ClocheSimulee.reglage(["-cloche", "vide"]) == .vide)
        #expect(ClocheSimulee.reglage(["-cloche", "injoignable"]) == .injoignable)
        #expect(ClocheSimulee.reglage(["-cloche", "12"]) == .boite(nombre: 12))
    }

    @MainActor @Test func uneResidenceQuiNeRepondPasSeDit() async {
        let lecteur = LecteurCloche(source: .simulee(.injoignable))
        await lecteur.lire()
        #expect(lecteur.lecture == .injoignable)
    }

    @MainActor @Test func laClocheLueGardeLesAlertesDeLaBoiteSimulee() async {
        let lecteur = LecteurCloche(source: .simulee(.boite(nombre: 10)))
        await lecteur.lire()
        guard case .lue(let cloche) = lecteur.lecture else {
            Issue.record("la cloche n'est pas lue : \(lecteur.lecture)")
            return
        }
        #expect(cloche.nonLues.count + cloche.lues.count == 10)
        #expect(cloche.nonLues.first?.urgente == true)
    }
}
