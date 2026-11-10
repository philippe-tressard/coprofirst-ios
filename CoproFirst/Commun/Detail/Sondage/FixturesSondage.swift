// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Les fiches de sondage que l'API simulée sert — en JSON, telles que GET /sondages/{id}
/// les renvoie (`SondageDetail`), lues par le type GÉNÉRÉ puis par le MÊME branchement
/// que le service réel (`DetailSondage(_:moi:)`). `scripts/verifier-fixtures.py` les
/// juge contre le schéma du serveur.
///
/// Trois cas : ouvert aux résultats publics, avec une option à préciser (12) ; ouvert
/// aux résultats masqués jusqu'à la clôture (11) ; clôturé, mon vote compris (9).
/// Tout est inventé : aucun nom de personne.
enum FixturesSondage {
    typealias Reponse = FixturesAcces.Reponse

    /// L'identifiant du compte simulé (celui de `moiCommunaute`).
    static let moi = 7

    /// GET /sondages/12, /11, /9 → `SondageDetail`, une fiche par élément.
    static let fiches = #"""
        [
          {"id": 12, "question": "Quel jour pour la fête des voisins ?",
           "description":
             "<p>Trois dates sont proposées. Les réponses sont ouvertes jusqu'à <strong>vendredi</strong>.</p>",
           "auteur_id": 1, "cloture": false, "cloture_forcee": false, "cloture_le": "2026-11-20T18:00:00",
           "cree_le": "2026-11-08T09:00:00", "mon_vote": null, "nouveau": true, "perimetre_cible": [],
           "public_cible": [], "resultats_publics": true, "resultats_visibles": true,
           "options": [
             {"id": 1, "libelle": "Samedi 6 juin", "ordre": 0, "champ_libre": false, "nb_votes": 14},
             {"id": 2, "libelle": "Samedi 13 juin", "ordre": 1, "champ_libre": false, "nb_votes": 9},
             {"id": 3, "libelle": "Dimanche 14 juin", "ordre": 2, "champ_libre": false, "nb_votes": 4},
             {"id": 4, "libelle": "Une autre date", "ordre": 3, "champ_libre": true, "nb_votes": 2,
              "reponses_libres": ["Le samedi 20 juin, après la brocante", "Plutôt un vendredi soir"]}
           ],
           "commentaires": [
             {"id": 31, "auteur_id": 1, "contenu": "Le conseil syndical fournira les tables et les chaises.",
              "cree_le": "2026-11-08T10:00:00", "auteur_nom": "Conseil syndical", "auteur_batiment": "Bât. A",
              "auteur_role": "Conseil syndical", "est_cs": true, "peut_supprimer": false},
             {"id": 32, "auteur_id": 5, "contenu": "Le 13 juin tombe pendant le marché : je préfère le 6.",
              "cree_le": "2026-11-09T18:30:00", "auteur_nom": "Voisin du bât. A", "auteur_batiment": "Bât. A",
              "auteur_role": "Résident", "est_cs": false, "peut_supprimer": false},
             {"id": 33, "auteur_id": 7, "contenu": "J'apporterai des guirlandes pour la cour.",
              "cree_le": "2026-11-09T20:15:00", "auteur_nom": "Camille Essai", "auteur_batiment": "Bât. B",
              "auteur_role": "Résident", "est_cs": false, "peut_supprimer": true}
           ]},
          {"id": 11, "question": "Faut-il installer des arceaux à vélos devant le bâtiment B ?",
           "description": "<p>Le devis est joint à l'affaire correspondante.</p>", "auteur_id": 1,
           "cloture": false, "cloture_forcee": false, "cloture_le": null, "cree_le": "2026-11-01T09:00:00",
           "mon_vote": null, "nouveau": false, "perimetre_cible": [], "public_cible": [],
           "resultats_publics": false, "resultats_visibles": false,
           "options": [
             {"id": 21, "libelle": "Oui", "ordre": 0, "champ_libre": false},
             {"id": 22, "libelle": "Non", "ordre": 1, "champ_libre": false},
             {"id": 23, "libelle": "Oui, mais ailleurs", "ordre": 2, "champ_libre": true}
           ],
           "commentaires": []},
          {"id": 9, "question": "Horaires d'ouverture du local à vélos", "description": null, "auteur_id": 1,
           "cloture": true, "cloture_forcee": false, "cloture_le": "2026-10-21T18:00:00",
           "cree_le": "2026-10-01T09:00:00", "mon_vote": 26, "nouveau": false, "perimetre_cible": [],
           "public_cible": [], "resultats_publics": true, "resultats_visibles": true,
           "options": [
             {"id": 25, "libelle": "De 7 h à 22 h", "ordre": 0, "champ_libre": false, "nb_votes": 29},
             {"id": 26, "libelle": "Sans restriction", "ordre": 1, "champ_libre": false, "nb_votes": 9},
             {"id": 27, "libelle": "Autre", "ordre": 2, "champ_libre": true, "nb_votes": 3,
              "reponses_libres": ["Fermé la nuit en hiver seulement"]}
           ],
           "commentaires": [
             {"id": 41, "auteur_id": 1, "contenu": "Les nouveaux horaires s'appliquent dès lundi.",
              "cree_le": "2026-10-22T09:00:00", "auteur_nom": "Conseil syndical", "auteur_batiment": "Bât. A",
              "auteur_role": "Conseil syndical", "est_cs": true, "peut_supprimer": false}
           ]}
        ]
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "fiches", schema: "SondageDetail", json: fiches)
    ]

    /// Lues comme le client généré les lit, puis par le branchement du service réel.
    static func lues() throws -> [DetailSondage] {
        try Relecture.generee([Components.Schemas.SondageDetail].self, json: fiches)
            .map { DetailSondage($0, moi: moi) }
    }
}
