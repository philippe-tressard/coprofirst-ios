// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Le parc que l'API simulée sert à « Badges & télécommandes » — le JSON de
/// `/acces/admin/vigiks` et `/acces/admin/telecommandes`, lu par le type GÉNÉRÉ puis par
/// le MÊME branchement que le service réel, et jugé contre le contrat par
/// `scripts/verifier-fixtures.py`. Les rangs suivent le NOM : « Basile Fictif » (rang 1)
/// passe avant « Alix Exemple » (rang 2) bien que son prénom vienne après (#55).
///
/// Tout est inventé : des porteurs qui n'appartiennent à personne.
enum FixturesBadgesCS {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /acces/admin/vigiks → `[AccesAdminOut]`.
    static let vigiks = #"""
        [
          {"id": 1, "code": "4521", "porteur_id": 21, "porteur_nom": "Alix Exemple", "porteur_rang": 2,
           "lot_id": 12, "lot_libelle": "Lot 12 — appartement", "perimetre_cible": ["Copropriété", "Bâtiment A"],
           "statut": "actif", "chez_locataire": false, "cree_le": "2026-02-10T09:00:00"},
          {"id": 2, "code": "417D5927", "porteur_id": 22, "porteur_nom": "Basile Fictif", "porteur_rang": 1,
           "lot_id": 21, "lot_libelle": "Lot 21 — appartement", "perimetre_cible": ["Copropriété", "Bâtiment B"],
           "statut": "perdu", "chez_locataire": true, "cree_le": "2026-03-02T09:00:00"},
          {"id": 4, "code": "7731", "porteur_id": 23, "porteur_nom": "Céleste Inventé", "porteur_rang": 3,
           "lot_id": null, "lot_libelle": null, "perimetre_cible": [], "statut": "suspendu",
           "chez_locataire": false, "cree_le": "2025-12-01T09:00:00"}
        ]
        """#

    /// GET /acces/admin/telecommandes → `[AccesAdminOut]`.
    static let telecommandes = #"""
        [
          {"id": 3, "code": "TC-0042", "porteur_id": 21, "porteur_nom": "Alix Exemple", "porteur_rang": 2,
           "lot_id": 104, "lot_libelle": "Lot 104 — parking", "perimetre_cible": ["Portail du parking"],
           "statut": "actif", "chez_locataire": false, "cree_le": "2026-04-18T09:00:00"},
          {"id": 5, "code": "TC-0007", "porteur_id": null, "porteur_nom": "", "porteur_rang": 0,
           "lot_id": 105, "lot_libelle": "Lot 105 — parking", "perimetre_cible": ["Portail du parking"],
           "statut": "actif", "chez_locataire": false, "cree_le": "2026-05-09T09:00:00"}
        ]
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "vigiks", schema: "AccesAdminOut", json: vigiks),
        Reponse(nom: "telecommandes", schema: "AccesAdminOut", json: telecommandes),
    ]

    /// Lu comme le client généré le lit, branché comme le service réel.
    static func parcLu() throws -> [AccesDuParc] {
        typealias Parc = [Components.Schemas.AccesAdminOut]
        return try Relecture.generee(Parc.self, json: vigiks).map { AccesDuParc(.vigik, $0) }
            + Relecture.generee(Parc.self, json: telecommandes).map { AccesDuParc(.telecommande, $0) }
    }
}
