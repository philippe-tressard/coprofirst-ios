// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Les fiches que l'API simulée sert à « Prestataires » — en JSON, tel que GET
/// /prestataires et /prestataires/archives les renvoient, lues par le type GÉNÉRÉ puis
/// par le MÊME branchement que le service réel (`Prestataire(_:)`), et jugées contre le
/// contrat par `scripts/verifier-fixtures.py`.
///
/// `telephones` (#125) : le contrôleur a saisi deux fois son numéro, le serveur n'en sert
/// qu'un. Des entreprises inventées,
/// aucun nom de personne, des numéros de la plage réservée à la fiction (01 99 00 …).
enum FixturesPrestataires {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /prestataires → `[PrestataireRead]`.
    static let prestataires = #"""
        [
          {"id": 1, "nom": "Ascenseurs du Parc (fictif)", "specialite": "ascenseur",
           "type_prestataire": "maintenance_depannage", "actif": true,
           "telephone": "01 99 00 00 11, 01 99 00 00 12", "telephones": ["01 99 00 00 11", "01 99 00 00 12"],
           "email": "contact@ascenseurs.exemple.fr", "adresse": "12 rue de l'Exemple, 75000 Paris",
           "description": "<p>Astreinte <strong>24 h/24</strong> pour les personnes bloquées en cabine.</p>",
           "contacts": [{"fonction": "Astreinte", "telephone": "01 99 00 00 13", "nom_affiche": ""}]},
          {"id": 2, "nom": "Contrôles Sécurité Exemple", "specialite": "incendie",
           "type_prestataire": "reglementaire", "actif": true,
           "telephone": "01 99 00 00 21,01 99 00 00 21", "telephones": ["01 99 00 00 21"],
           "email": "planning@controles.exemple.fr"},
          {"id": 3, "nom": "Eaux de la Ville (fictif)", "specialite": "eau", "type_prestataire": "gestion",
           "actif": true, "telephone": "01 99 00 00 31", "telephones": ["01 99 00 00 31"]},
          {"id": 4, "nom": "Peinture & Façades Exemple", "specialite": "facade", "type_prestataire": "travaux",
           "actif": true, "telephone": null, "telephones": []}
        ]
        """#

    /// GET /prestataires/archives → `[PrestataireRead]`.
    static let archives = #"""
        [
          {"id": 9, "nom": "Ancien jardinier (fictif)", "specialite": "espaces_verts",
           "type_prestataire": "maintenance_depannage", "actif": false, "archivee": true, "telephones": []}
        ]
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "prestataires", schema: "PrestataireRead", json: prestataires),
        Reponse(nom: "archives", schema: "PrestataireRead", json: archives),
    ]

    static func lus(archives: Bool = false) throws -> [Prestataire] {
        let json = archives ? Self.archives : prestataires
        return try Relecture.generee([Components.Schemas.PrestataireRead].self, json: json).map(Prestataire.init)
    }
}
#endif
