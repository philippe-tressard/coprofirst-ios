// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Les réponses du serveur que l'API simulée sert pour « Mes lots & accès » — en
/// JSON, telles que les routes les renvoient, lues par les types GÉNÉRÉS puis par le
/// MÊME branchement que le service réel (`LotDuCompte.init(_:)`, `AccesDetenu.init(_:type:)`).
///
/// 🔴 Pourquoi du JSON et non des modèles construits à la main (#13, bogue du
/// 05/11/2026) : la simulation fournissait un champ `type` que `/acces/mes-vigiks` ne
/// sert pas. Les tests passaient, l'iPhone affichait une erreur. `scripts/verifier-fixtures.py`
/// confronte chaque réponse ci-dessous, déclarée dans `parSchema`, au schéma de sa route :
/// aucun champ que le serveur ne sert, aucun champ requis qui manque (#20).
///
/// Tout est inventé : aucun nom de personne, des numéros de la plage réservée à la
/// fiction (01 99 00 …), des adresses `exemple.fr`.
enum FixturesAcces {
    /// GET /lots/mes-lots → `[LotRead]`.
    static let mesLots = #"""
        [
          {"id": 15, "numero": "15", "type": "appartement", "type_appartement": "T3", "etage": 2,
           "superficie": 64.5, "batiment_id": 1, "batiment_nom": "Bât. A", "est_logement_de_reference": true,
           "type_lien": "propriétaire", "nature": "logement", "numero_usage": "21",
           "libelle_type": "Appartement", "libelle_type_complet": "Appartement – T3", "libelle_nature": "Logement",
           "nom_du_lot": "Logement 15", "etage_libelle": "2ème",
           "perimetres": [
             {"code": "A", "libelle": "Bâtiment A", "relation": "situe_dans", "derive": true},
             {"code": "A-ESC", "libelle": "Escalier A", "relation": "desservi_par", "derive": true}
           ],
           "alertes": [
             {"code": "etage_declare", "gravite": "information",
              "message": "L'étage de ce lot vient de votre déclaration ; le fichier du syndic ne le précise pas.",
              "lots": ["15"]}
           ]},
          {"id": 417, "numero": "417", "type": "cave", "etage": -1, "superficie": 4, "batiment_nom": "Bât. A",
           "type_lien": "propriétaire", "libelle_type": "Cave", "libelle_type_complet": "Cave",
           "nom_du_lot": "Cave 417", "etage_libelle": "SS 1",
           "perimetres": [{"code": "A-SS", "libelle": "Sous-sol A", "relation": "situe_dans"}], "alertes": []},
          {"id": 450, "numero": "450", "type": "parking", "etage": -2, "batiment_nom": "Bât. B",
           "type_lien": "propriétaire", "numero_usage": "5 & 6", "libelle_type": "Parking",
           "libelle_type_complet": "Parking", "nom_du_lot": "Place 450", "etage_libelle": "SS 2",
           "perimetres": [{"code": "B-P2", "libelle": "Parking niveau -2", "relation": "situe_dans"}], "alertes": []}
        ]
        """#

    /// GET /acces/mes-vigiks → `[AccesPorteur]` (sans `type` : c'est la route qui le dit).
    static let mesVigiks = #"""
        [
          {"id": 11, "code": "A4F21C07", "statut": "actif", "chez_locataire": false, "lot_id": 15,
           "perimetre_cible": [], "perimetre_libelle": "", "lot_libelle": "Logement 15",
           "cree_le": "2025-01-10T09:00:00"},
          {"id": 12, "code": "A4F21C08", "statut": "actif", "chez_locataire": false, "lot_id": 15,
           "perimetre_cible": [], "perimetre_libelle": "", "lot_libelle": "Logement 15",
           "cree_le": "2025-01-10T09:00:00"},
          {"id": 13, "code": "9B0E33D1", "statut": "perdu", "chez_locataire": false, "lot_id": 15,
           "perimetre_cible": [], "perimetre_libelle": "", "lot_libelle": "Logement 15",
           "cree_le": "2024-06-02T14:30:00"}
        ]
        """#

    /// GET /acces/mes-telecommandes → `[AccesPorteur]`.
    static let mesTelecommandes = #"""
        [
          {"id": 21, "code": "TC-2048", "statut": "actif", "chez_locataire": false, "lot_id": 450,
           "perimetre_cible": [], "perimetre_libelle": "", "lot_libelle": "Place 450",
           "cree_le": "2025-03-01T10:00:00"}
        ]
        """#

    /// GET /bailleur/tous-les-baux (le compte simulé est au conseil) → `[BailOut]`.
    static let baux = #"""
        [
          {"id": 3, "lot_id": 31, "bailleur_id": 70, "locataire_id": 81, "locataire_nom": "du lot 31",
           "locataire_prenom": "Locataire", "locataire_email": "locataire.31@exemple.fr",
           "locataire_nom_affiche": "Locataire DU LOT 31",
           "locataire_telephone": "01 99 00 00 31", "date_entree": "2025-09-01", "date_sortie_prevue": null,
           "date_sortie_reelle": null, "statut": "actif",
           "notes": "<p>Préavis d'<strong>un mois</strong> (zone tendue).</p>",
           "cree_le": "2025-08-20T10:00:00", "mis_a_jour_le": "2025-09-01T10:00:00",
           "objets": [
             {"id": 1, "bail_id": 3, "type": "cle", "libelle": "Clé de la porte palière", "quantite": 2,
              "reference": null, "statut": "en_possession", "remis_le": "2025-09-01", "rendu_le": null,
              "notes": null, "cree_le": "2025-09-01T10:00:00"},
             {"id": 2, "bail_id": 3, "type": "vigik", "libelle": "Badge du hall", "quantite": 1,
              "reference": "A4F21C09", "statut": "en_possession", "remis_le": "2025-09-01", "rendu_le": null,
              "notes": null, "cree_le": "2025-09-01T10:00:00"}
           ]},
          {"id": 4, "lot_id": 32, "bailleur_id": 71, "locataire_id": null, "locataire_nom": "du lot 32",
           "locataire_prenom": "Locataire", "locataire_email": null, "locataire_telephone": null,
           "locataire_nom_affiche": "Locataire DU LOT 32",
           "date_entree": "2023-02-15", "date_sortie_prevue": "2026-11-30", "date_sortie_reelle": null,
           "statut": "en_cours_sortie", "notes": null, "cree_le": "2023-02-01T10:00:00",
           "mis_a_jour_le": "2026-10-01T10:00:00", "objets": []},
          {"id": 2, "lot_id": 31, "bailleur_id": 70, "locataire_id": 80, "locataire_nom": "du lot 31",
           "locataire_prenom": "Ancien locataire", "locataire_email": null, "locataire_telephone": null,
           "locataire_nom_affiche": "Ancien locataire DU LOT 31",
           "date_entree": "2021-03-01", "date_sortie_prevue": "2025-06-30", "date_sortie_reelle": "2025-07-02",
           "statut": "termine", "notes": null, "cree_le": "2021-02-15T10:00:00",
           "mis_a_jour_le": "2025-07-02T10:00:00",
           "objets": [
             {"id": 3, "bail_id": 2, "type": "telecommande", "libelle": "Télécommande du parking", "quantite": 1,
              "reference": null, "statut": "rendu", "remis_le": "2021-03-01", "rendu_le": "2025-07-02",
              "notes": null, "cree_le": "2021-03-01T10:00:00"}
           ]}
        ]
        """#

    /// GET /bailleur/mon-bail (`-compte locataire`) → `BailLocataireOut`, à la forme du
    /// serveur v3.88.1 : l'étage du lot en clair (`lot_etage_libelle`, contrat 1.21.0, #127).
    static let monBail = #"""
        {"id": 3, "lot_id": 15, "statut": "actif", "lot_batiment_nom": "Bât. A", "lot_numero": "15",
         "lot_type": "appartement", "lot_type_appartement": "T3", "lot_etage": 2, "lot_etage_libelle": "2ème",
         "lot_superficie": 64.5, "date_entree": "2025-09-01", "date_sortie_prevue": null,
         "bailleur_prenom": "Sacha", "bailleur_nom": "Exemple", "bailleur_nom_affiche": "Sacha EXEMPLE",
         "bailleur_email": "bailleur@exemple.fr",
         "bailleur_telephone": "01 99 00 00 70", "acces": []}
        """#

    /// Une réponse simulée et le schéma de sa route (`components/schemas`).
    struct Reponse: Sendable {
        let nom: String
        let schema: String
        let json: String
    }

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "mesLots", schema: "LotRead", json: mesLots),
        Reponse(nom: "mesVigiks", schema: "AccesPorteur", json: mesVigiks),
        Reponse(nom: "mesTelecommandes", schema: "AccesPorteur", json: mesTelecommandes),
        Reponse(nom: "baux", schema: "BailOut", json: baux),
        Reponse(nom: "monBail", schema: "BailLocataireOut", json: monBail),
    ]

    // MARK: - Lues comme le client généré les lit

    static func lots() throws -> [LotDuCompte] {
        try lire([Components.Schemas.LotRead].self, mesLots).map(LotDuCompte.init)
    }

    static func detenus(_ type: TypeAcces) throws -> [AccesDetenu] {
        let json = type == .vigik ? mesVigiks : mesTelecommandes
        return try lire([Components.Schemas.AccesPorteur].self, json).map { AccesDetenu($0, type: type) }
    }

    static func bauxLus() throws -> [Bail] {
        try lire([Components.Schemas.BailOut].self, baux).map(Bail.init)
    }

    static func monBailLu() throws -> BailDuLocataire {
        BailDuLocataire(try lire(Components.Schemas.BailLocataireOut.self, monBail))
    }

    /// Le décodage du client généré : clés du contrat, dates par `TranscodeurDates`.
    static func lire<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try Relecture.generee(type, json: json)
    }
}
#endif
