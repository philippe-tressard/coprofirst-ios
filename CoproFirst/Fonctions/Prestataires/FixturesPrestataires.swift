// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Les fiches que l'API simulée sert à « Prestataires » — en JSON, tel que GET
/// /prestataires et /prestataires/archives les renvoient, lues par le type GÉNÉRÉ puis
/// par le MÊME branchement que le service réel (`Prestataire.lus`), et jugées contre le
/// contrat par `scripts/verifier-fixtures.py`.
///
/// À la forme du serveur v3.88.1 : `telephones` (contrat 1.20.0, #125) — le contrôleur
/// a saisi deux fois son numéro, le serveur n'en sert qu'un. Des entreprises inventées,
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
           "actif": true, "telephone": null, "telephones": []},
          {"id": 5, "nom": "Protection Incendie Exemple", "specialite": "incendie",
           "type_prestataire": "reglementaire", "actif": true, "telephone": "01 99 00 00 51",
           "telephones": ["01 99 00 00 51"]}
        ]
        """#

    /// GET /prestataires/archives → `[PrestataireRead]`.
    static let archives = #"""
        [
          {"id": 9, "nom": "Ancien jardinier (fictif)", "specialite": "espaces_verts",
           "type_prestataire": "maintenance_depannage", "actif": false, "archivee": true, "telephones": []}
        ]
        """#

    /// GET /prestataires/contrats → `[ContratRead]`, à la forme du serveur v3.91.0 (contrat
    /// 1.29.0, #185) : le contrat des extincteurs est résilié au 30 novembre et remplacé
    /// par celui d'un autre prestataire dès le 1er décembre — les deux cartes le disent.
    static let contrats = #"""
        [
          {"id": 1, "copropriete_id": 1, "prestataire_id": 1, "type_equipement": "ascenseur",
           "libelle": "Maintenance des deux ascenseurs", "numero_contrat": "ASC-2024-118",
           "date_debut": "2024-01-01", "duree_initiale_valeur": 3, "duree_initiale_unite": "ans",
           "frequence_type": "mois", "frequence_valeur": 1, "frequence_libelle": "↺ Mensuel",
           "prochaine_visite": "2026-11-18", "actif": true,
           "notes": "<p>Visite mensuelle ; remplacement des câbles prévu en 2027.</p>",
           "resilie_le": null, "remplace_par_id": null, "resilie": false, "remplace_par": null, "remplace": []},
          {"id": 2, "copropriete_id": 1, "prestataire_id": 2, "type_equipement": "incendie",
           "libelle": "Vérification des extincteurs", "date_debut": "2023-06-01", "frequence_type": "fois_par_an",
           "frequence_valeur": 1, "frequence_libelle": "↺ 1×/an", "prochaine_visite": "2026-09-30",
           "actif": true, "date_fin": "2026-11-30", "date_preavis": null, "urgence_echeance": null,
           "resilie_le": "2026-11-30", "remplace_par_id": 4, "resilie": false,
           "remplace_par": {"id": 4, "libelle": "Vérification des extincteurs", "prestataire_id": 5,
                            "prestataire_nom": "Protection Incendie Exemple", "date_debut": "2026-12-01",
                            "resilie_le": null},
           "remplace": []},
          {"id": 3, "copropriete_id": 1, "prestataire_id": 3, "type_equipement": "autre",
           "libelle": "Abonnement eau froide", "date_debut": "2020-01-01", "actif": true},
          {"id": 4, "copropriete_id": 1, "prestataire_id": 5, "type_equipement": "incendie",
           "libelle": "Vérification des extincteurs", "date_debut": "2026-12-01", "frequence_type": "fois_par_an",
           "frequence_valeur": 1, "frequence_libelle": "↺ 1×/an", "prochaine_visite": "2026-12-15",
           "actif": true, "resilie_le": null, "remplace_par_id": null, "resilie": false, "remplace_par": null,
           "remplace": [{"id": 2, "libelle": "Vérification des extincteurs", "prestataire_id": 2,
                         "prestataire_nom": "Contrôles Sécurité Exemple", "date_debut": "2023-06-01",
                         "resilie_le": "2026-11-30"}]}
        ]
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "prestataires", schema: "PrestataireRead", json: prestataires),
        Reponse(nom: "archives", schema: "PrestataireRead", json: archives),
        Reponse(nom: "contrats", schema: "ContratRead", json: contrats),
    ]

    /// La résiliation et le remplacement, servis au-dessus du plancher (#185).
    static let auDessus = AuDessusDuPlancher(
        schema: "ContratRead", champs: ["resilie_le", "remplace_par_id", "resilie", "remplace_par", "remplace"],
        contrat: "1.29.0")

    /// Les contrats, lus comme le client généré les lit, branchés comme le service réel.
    static func contratsLus() throws -> [Contrat] {
        Contrat.lus(
            try Relecture.generee([Components.Schemas.ContratRead].self, json: contrats), corps: Data(contrats.utf8))
    }

    static func lus(archives: Bool = false) throws -> [Prestataire] {
        let json = archives ? Self.archives : prestataires
        return try Relecture.generee([Components.Schemas.PrestataireRead].self, json: json).map(Prestataire.init)
    }
}
#endif
