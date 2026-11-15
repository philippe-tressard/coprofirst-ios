// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Les gestes qu'une page ouvre à CE lecteur, tels que l'API simulée les sert — en JSON, à
/// la forme de leurs routes (`GET /faq/gestes`, `GET /sondages/gestes`, contrat 1.20.0,
/// #87), lus par les types GÉNÉRÉS et jugés par `scripts/verifier-fixtures.py`.
///
/// Le serveur ouvre la rédaction de la FAQ et la création d'un sondage à qui modère
/// (`require_cs_or_admin`) : l'API simulée sert la réponse du modérateur ou celle du
/// résident, selon le compte simulé — l'écran, lui, ne lit que le champ servi.
enum FixturesGestesServis {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /faq/gestes → `GestesFaq`.
    static let faqModerateur = #"""
        {"peut_rediger": true}
        """#
    static let faqResident = #"""
        {"peut_rediger": false}
        """#

    /// GET /sondages/gestes → `GestesSondages`.
    static let sondagesModerateur = #"""
        {"peut_creer": true}
        """#
    static let sondagesResident = #"""
        {"peut_creer": false}
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "faqModerateur", schema: "GestesFaq", json: faqModerateur),
        Reponse(nom: "faqResident", schema: "GestesFaq", json: faqResident),
        Reponse(nom: "sondagesModerateur", schema: "GestesSondages", json: sondagesModerateur),
        Reponse(nom: "sondagesResident", schema: "GestesSondages", json: sondagesResident),
    ]

    /// `peut_rediger`, tel que le serveur le servirait au compte simulé.
    static func peutRedigerLaFAQ(moderateur: Bool) throws -> Bool {
        try Relecture.generee(Components.Schemas.GestesFaq.self, json: moderateur ? faqModerateur : faqResident)
            .peutRediger
    }

    /// `peut_creer`, tel que le serveur le servirait au compte simulé.
    static func peutCreerUnSondage(moderateur: Bool) throws -> Bool {
        try Relecture.generee(
            Components.Schemas.GestesSondages.self, json: moderateur ? sondagesModerateur : sondagesResident
        ).peutCreer
    }
}
#endif
