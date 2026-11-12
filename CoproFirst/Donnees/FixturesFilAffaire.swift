// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Les comptes rendus et la synthèse que l'API simulée sert au fil d'une affaire (#178) —
/// en JSON, à la forme de leurs routes, lus par les types GÉNÉRÉS puis par les mêmes
/// initialiseurs que le service réel, et jugés par `scripts/verifier-fixtures.py`.
/// Tout est inventé : aucun nom de personne.
enum FixturesFilAffaire {
    typealias Reponse = FixturesAcces.Reponse

    // swiftlint:disable line_length
    /// GET /points-conseil/affaires/41 → `[CrPublieRead]` : deux points où la fuite a été abordée.
    static let comptesRendus = #"""
        [
          {"cr_id": 7, "point_id": 3, "debut": "2026-11-10T18:00:00", "a_distance": false,
           "ou": "En salle", "lieu": "Local du conseil", "conseil_seul": false, "pdf_disponible": false,
           "contenu": "<p>Le syndic relance le plombier ; un second devis est demandé pour la reprise de l'étanchéité.</p>"},
          {"cr_id": 5, "point_id": 2, "debut": "2026-11-09T18:00:00", "a_distance": true,
           "ou": "À distance", "conseil_seul": false, "pdf_disponible": false,
           "contenu": "<p>Fuite signalée ; le seau reste en place jusqu'à l'intervention.</p>"}
        ]
        """#
    // swiftlint:enable line_length

    /// GET /tickets/31/synthese → `SyntheseEtat` : la synthèse validée du portail.
    static let synthese = #"""
        {"en_attente": false, "produisible": false,
         "synthese": {"id": 2, "ticket_id": 31, "statut": "validee", "assiste_ia": false,
                      "synthese": "La carte électronique du portail a été remplacée sous garantie.",
                      "difficultes": "Deux jours d'attente de la pièce.",
                      "amelioration": "Garder une télécommande de secours au local du conseil.",
                      "validee_le": "2026-11-08T10:00:00"}}
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "comptesRendus", schema: "CrPublieRead", json: comptesRendus),
        Reponse(nom: "synthese", schema: "SyntheseEtat", json: synthese),
    ]

    /// Les comptes rendus de l'affaire `id`, lus comme le service réel les lit.
    static func comptesRendus(_ id: Int) throws -> [CompteRenduAffaire] {
        guard id == 41 else { return [] }
        return try Relecture.generee([Components.Schemas.CrPublieRead].self, json: comptesRendus)
            .map(CompteRenduAffaire.init).sorted { $0.debut > $1.debut }
    }

    /// La synthèse de l'affaire `id`, lue comme le service réel la lit.
    static func synthese(_ id: Int) throws -> SyntheseAffaire? {
        guard id == 31 else { return nil }
        return SyntheseAffaire(try Relecture.generee(Components.Schemas.SyntheseEtat.self, json: synthese))
    }
}
#endif
