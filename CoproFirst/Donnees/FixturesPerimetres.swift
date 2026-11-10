// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// L'arbre des périmètres que l'API simulée sert (`GET /perimetres`) — en JSON, lu par le
/// type GÉNÉRÉ puis par `Perimetre(lu:)`, comme le service réel. La forme de l'arbre semé
/// (`seed/patrimoine.py`) : une racine désignée par défaut, le regroupement « Bâtiments »
/// (non ciblable) et ses bâtiments, deux espaces du bâtiment A, deux lieux racines ; le carnet
/// filtre sur `bat_a`.
///
/// 🔴 Ses CODES sont la référence de toute l'API simulée (#64) : `scripts/verifier-fixtures.py`
/// refuse un `perimetre_cible` qui n'en cite pas un — un libellé (« Copropriété ») à la
/// place d'un code y avait caché les codes bruts (« bat:2 ») affichés par Badges.
enum FixturesPerimetres {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /perimetres → `[PerimetreRead]`.
    static let arbre = #"""
        [
          {"id": 1, "code": "copropriete", "parent": null, "libelle": "Toute la copropriété",
           "libelle_court": "Copropriété", "description": "", "icone": null, "batiment_id": null,
           "profondeur": 0, "ordre": 0, "actif": true, "portee_globale": true, "concerne_tous": true,
           "selectionnable": true, "privatif": false, "hors_copropriete": false, "utilise": true,
           "par_defaut": true},
          {"id": 6, "code": "batiments", "parent": null, "libelle": "Bâtiments", "libelle_court": "Bâtiments",
           "description": "", "icone": null, "batiment_id": null, "profondeur": 0, "ordre": 10, "actif": true,
           "portee_globale": false, "concerne_tous": false, "selectionnable": false, "privatif": false,
           "hors_copropriete": false, "utilise": false, "par_defaut": false},
          {"id": 2, "code": "bat_a", "parent": "batiments", "libelle": "Bâtiment A", "libelle_court": "Bât. A",
           "description": "", "icone": null, "batiment_id": 1, "profondeur": 1, "ordre": 1, "actif": true,
           "portee_globale": false, "concerne_tous": false, "selectionnable": true, "privatif": false,
           "hors_copropriete": false, "utilise": true, "par_defaut": false},
          {"id": 7, "code": "bat_a/hall", "parent": "bat_a", "libelle": "Hall d'entrée", "libelle_court": "Hall",
           "description": "", "icone": null, "batiment_id": 1, "profondeur": 2, "ordre": 1, "actif": true,
           "portee_globale": false, "concerne_tous": false, "selectionnable": true, "privatif": false,
           "hors_copropriete": false, "utilise": false, "par_defaut": false},
          {"id": 8, "code": "bat_a/toit", "parent": "bat_a", "libelle": "Toit", "libelle_court": "Toit",
           "description": "", "icone": null, "batiment_id": 1, "profondeur": 2, "ordre": 2, "actif": true,
           "portee_globale": false, "concerne_tous": false, "selectionnable": true, "privatif": false,
           "hors_copropriete": false, "utilise": false, "par_defaut": false},
          {"id": 3, "code": "bat_b", "parent": "batiments", "libelle": "Bâtiment B", "libelle_court": "Bât. B",
           "description": "", "icone": null, "batiment_id": 2, "profondeur": 1, "ordre": 2, "actif": true,
           "portee_globale": false, "concerne_tous": false, "selectionnable": true, "privatif": false,
           "hors_copropriete": false, "utilise": true, "par_defaut": false},
          {"id": 4, "code": "parking", "parent": null, "libelle": "Parking", "libelle_court": "Parking",
           "description": "", "icone": null, "batiment_id": null, "profondeur": 0, "ordre": 3, "actif": true,
           "portee_globale": false, "concerne_tous": false, "selectionnable": true, "privatif": false,
           "hors_copropriete": false, "utilise": true, "par_defaut": false},
          {"id": 5, "code": "jardin", "parent": null, "libelle": "Jardin", "libelle_court": "Jardin",
           "description": "", "icone": null, "batiment_id": null, "profondeur": 0, "ordre": 4, "actif": true,
           "portee_globale": false, "concerne_tous": false, "selectionnable": true, "privatif": false,
           "hors_copropriete": false, "utilise": true, "par_defaut": false}
        ]
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "arbre", schema: "PerimetreRead", json: arbre)
    ]

    /// Lu comme le client généré le lit, branché comme le service réel (actifs seulement).
    static func lus() throws -> [Perimetre] {
        try Relecture.generee([Components.Schemas.PerimetreRead].self, json: arbre).filter(\.actif)
            .map(Perimetre.init(lu:))
    }
}
