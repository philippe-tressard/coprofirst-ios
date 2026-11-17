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
    /// un avis sans affaire. L'avis de 2025 est celui du compte simulé (`peut_modifier`) :
    /// sa première ligne est une phrase générée, que la correction recoche.
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
                        "exercice_annee": 2025, "exercice_libelle": "2025", "peut_modifier": true}]}
           ],
           "avis_generaux": []}
        ]
        """#

    /// Les affaires qu'un avis peut juger (`GET /prestataires/affaires-a-noter`), pour les
    /// Ascenseurs du Parc : les siennes d'abord, puis les autres — inventées.
    static let affaires = #"""
        [
          {"id": 45, "numero": "A-0045", "titre": "Contrôle annuel de l'ascenseur", "statut": "resolu",
           "intervient": true, "intervenants": "Ascenseurs du Parc (fictif)"},
          {"id": 38, "numero": "A-0038", "titre": "Cabine bloquée au 3e étage", "statut": "resolu",
           "intervient": true, "intervenants": "Ascenseurs du Parc (fictif)"},
          {"id": 21, "numero": "A-0021", "titre": "Porte palière qui grince", "statut": "resolu",
           "intervient": true, "intervenants": "Ascenseurs du Parc (fictif)"},
          {"id": 52, "numero": "A-0052", "titre": "Infiltration en toiture", "statut": "en_cours",
           "intervient": false, "intervenants": "Toitures de l'Ouest (fictif)"},
          {"id": 50, "numero": "A-0050", "titre": "Éclairage du hall", "statut": "ouvert",
           "intervient": false, "intervenants": ""}
        ]
        """#

    /// Les prestataires qui ont des avis simulés.
    static let prestataires = [1]

    /// Chaque réponse et le schéma de sa route, pour le juge.
    static let parSchema: [Reponse] = [
        Reponse(nom: "ascenseurs", schema: "ExerciceInterventions", json: ascenseurs),
        Reponse(nom: "affaires", schema: "AffaireAvis", json: affaires),
    ]

    /// Le récapitulatif du prestataire `id` : celui des ascenseurs, rien pour les autres.
    static func lus(_ id: Int) throws -> [ExerciceAvis] {
        guard id == 1 else { return [] }
        return try Relecture.generee([Components.Schemas.ExerciceInterventions].self, json: ascenseurs)
            .map(ExerciceAvis.init)
    }

    /// Les affaires à noter : pour un autre prestataire, aucune n'est encore la sienne.
    static func affairesLues(_ prestataire: Int) throws -> [AffaireANoter] {
        try Relecture.generee([Components.Schemas.AffaireAvis].self, json: affaires).map {
            var affaire = AffaireANoter($0)
            if prestataire != 1 { affaire.intervient = false }
            return affaire
        }
    }
}
#endif
