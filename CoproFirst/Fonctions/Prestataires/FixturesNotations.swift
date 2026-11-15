// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Le récapitulatif des avis que l'API simulée sert (`GET /prestataires/{id}/interventions`,
/// R3d, #207) — en JSON, à la forme du serveur v3.101.0, lu par le type GÉNÉRÉ puis par le
/// MÊME branchement que le service réel (`ExerciceAvis.init`), et jugé contre le contrat
/// par `scripts/verifier-fixtures.py`. Des affaires et des avis inventés, aucun nom de
/// personne : l'auteur est « Conseil syndical ».
enum FixturesNotations {
    typealias Reponse = FixturesAcces.Reponse

    /// Ascenseurs du Parc (1) : deux exercices — trois avis, une intervention non notée,
    /// un avis sans affaire.
    static let ascenseurs = #"""
        [
          {"annee": 2026, "libelle": "2026", "nb_interventions": 2, "nb_notees": 1,
           "compte": {"excellent": 2},
           "interventions": [
             {"ticket_id": 45, "numero": "A-0045", "titre": "Contrôle annuel de l'ascenseur",
              "date": "2026-11-10T13:00:00",
              "avis": [{"id": 11, "prestataire_id": 1, "note": 5, "etat": "excellent",
                        "commentaire": "Points forts : délai respecté, travail soigné.",
                        "auteur_nom": "Conseil syndical", "cree_le": "2026-11-12T09:00:00",
                        "ticket_id": 45, "ticket_titre": "Contrôle annuel de l'ascenseur",
                        "exercice_annee": 2026, "exercice_libelle": "2026", "peut_modifier": false}]},
             {"ticket_id": 38, "numero": "A-0038", "titre": "Cabine bloquée au 3e étage",
              "date": "2026-03-02T08:30:00", "avis": []}
           ],
           "avis_generaux": [{"id": 12, "prestataire_id": 1, "note": 5, "etat": "excellent",
                              "commentaire": "Astreinte joignable de nuit.",
                              "auteur_nom": "Conseil syndical", "cree_le": "2026-06-20T18:00:00",
                              "exercice_annee": 2026, "exercice_libelle": "2026", "peut_modifier": false}]},
          {"annee": 2025, "libelle": "2025", "nb_interventions": 1, "nb_notees": 1,
           "compte": {"neutre": 1},
           "interventions": [
             {"ticket_id": 21, "numero": "A-0021", "titre": "Porte palière qui grince",
              "date": "2025-09-14T10:00:00",
              "avis": [{"id": 9, "prestataire_id": 1, "note": 3, "etat": "neutre",
                        "commentaire": "Points faibles : retard.\nRéparé au second passage.",
                        "auteur_nom": "Conseil syndical", "cree_le": "2025-09-30T11:00:00",
                        "ticket_id": 21, "ticket_titre": "Porte palière qui grince",
                        "exercice_annee": 2025, "exercice_libelle": "2025", "peut_modifier": false}]}
           ],
           "avis_generaux": []}
        ]
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge.
    static let parSchema: [Reponse] = [
        Reponse(nom: "ascenseurs", schema: "ExerciceInterventions", json: ascenseurs)
    ]

    /// Le récapitulatif du prestataire `id` : celui des ascenseurs, rien pour les autres.
    static func lus(_ id: Int) throws -> [ExerciceAvis] {
        guard id == 1 else { return [] }
        return try Relecture.generee([Components.Schemas.ExerciceInterventions].self, json: ascenseurs)
            .map(ExerciceAvis.init)
    }
}
#endif
