// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// « Écrans du hall » de l'Espace CS (#295) : la saisie lue comme le site la lit, la liste
/// servie lue par le type généré, et les gestes de l'API simulée.
struct EcransHallTests {
    @Test func lesDeuxServicesPortentLOnglet() {
        let _: any ServiceEcransCS = ServiceAPI()
        let _: any ServiceEcransCS = ServiceSimule(delai: .zero)
    }

    /// `lettres` du site : majuscules, tiret, espaces et casse libres ; huit lettres, un nom
    /// et UN périmètre font une saisie complète.
    @Test func leCodeSeLitLettreALettreEtLaSaisieSuitLaRegleDuSite() {
        var saisie = SaisieAppairage(code: " bcdf-ghjk ", nom: "  ")
        #expect(saisie.lettres == "BCDFGHJK")
        #expect(!saisie.complete, "sans nom")
        saisie.nom = " Hall A "
        #expect(saisie.nomSaisi == "Hall A")
        #expect(!saisie.complete, "sans périmètre")
        saisie.perimetres.codes = ["bat_a"]
        #expect(saisie.complete)
        saisie.code = "BCDF-GHJ"
        #expect(!saisie.complete, "sept lettres")
        saisie.code = "BCDF-GHJK-É1"
        #expect(saisie.lettres == "BCDFGHJK", "ni accent ni chiffre")
        #expect(saisie.perimetres.unique, "un écran n'a qu'un lieu")
    }

    @Test func laListeServieSeLitParLeTypeGenere() throws {
        let ecrans = try FixturesEcransCS.ecransLus()
        #expect(ecrans.map(\.id) == [3, 1, 4])
        #expect(ecrans[0].lieu == "Bât. A › Hall")
        #expect(ecrans[2].lieu == nil, "le périmètre par défaut se tait")
        #expect(ecrans[1].echu && !ecrans[0].echu)
        #expect(TextesEcransCS.lecture(ecrans[2]).hasPrefix(TextesEcransCS.aucuneLecture))
        #expect(TextesEcransCS.lecture(ecrans[0]).contains("appairé le 02/11/2026"))
    }

    @Test func unCodeInconnuRendLaPhraseDuServeurEtLeBonAppaire() async throws {
        let service = ServiceSimule(delai: .zero)
        let residence = ServiceSimule.residence
        var saisie = SaisieAppairage(code: "BCDF-GHJX", nom: "Hall du parking")
        saisie.perimetres.codes = ["parking"]
        await #expect(throws: ErreurService.refus(.init(phrase: FixturesEcransCS.codeInconnu))) {
            try await service.appairer(saisie, dans: residence)
        }
        saisie.code = "bcdf ghjk"
        let appaire = try await service.appairer(saisie, dans: residence)
        #expect(appaire.nom == "Hall du parking")
        let apres = try await service.ecrans(dans: residence)
        #expect(apres.contains { $0.nom == "Hall du parking" && $0.perimetre == "parking" })

        try await service.retirer(3, dans: residence)
        #expect(try await service.ecrans(dans: residence).allSatisfy { $0.id != 3 })
    }
}
