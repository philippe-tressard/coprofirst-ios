// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// « À propos » : la mention du pied de page du site et ses textes légaux.
struct AProposTests {
    @Test func laMentionDeLAnneeEstCelleDuSite() {
        #expect(AProposResidence.mentionAnnee(debut: nil, courante: 2026) == "© 2026")
        #expect(AProposResidence.mentionAnnee(debut: 2026, courante: 2026) == "© 2026")
        #expect(AProposResidence.mentionAnnee(debut: 2024, courante: 2026) == "© 2024–2026")
    }

    @Test func lesClesServiesSontLuesEtUnTexteVideSeTait() {
        let lu = AProposResidence(
            config: [TextesDuPied.cleAnneeDebut: " 2025 ", TextesDuPied.cleTexte: "  "],
            legal: ["mentions_legales": "<p>Éditeur</p>", "politique_confidentialite": ""])
        #expect(lu.anneeDebut == 2025 && lu.texte == nil)
        #expect(lu.mentionsLegales == "<p>Éditeur</p>" && lu.confidentialite == nil)
    }

    @Test func lesDeuxServicesSaventLire() {
        // À la compilation : `Parcours.serviceAPropos` force la conversion.
        let _: any ServiceAPropos = ServiceSimule()
        let _: any ServiceAPropos = ServiceAPI()
    }
}
