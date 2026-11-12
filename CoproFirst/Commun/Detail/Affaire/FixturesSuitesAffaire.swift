// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// L'Historique de l'affaire 41 tel que le serveur le sert avec les gestes de chaque
/// entrée — en JSON, tel que GET /tickets/41/evolutions le renvoie à un ADMINISTRATEUR
/// depuis coprofirst v3.84.0 (contrat 1.19.0, #93) : un changement d'état et un
/// commentaire, qu'il corrige et efface ; une réponse, qui appartient à son auteur.
/// `scripts/verifier-fixtures.py` le juge contre le schéma du serveur ; les gestes s'y
/// relisent par le MÊME branchement que le service réel (`avecGestesServis`).
///
/// Les entrées elles-mêmes (texte, dates) restent celles de `ServiceSimule.affaires` :
/// `SuiteHistoriqueTests` refuse qu'elles divergent d'ici. Aucun nom de personne.
enum FixturesSuitesAffaire {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /tickets/41/evolutions → `[TicketEvolutionRead]`, dans l'ordre de `cree_le`.
    static let evolutions = #"""
        [
          {"id": 1, "ticket_id": 41, "type": "etat", "cree_le": "2026-11-09T10:00:00",
           "auteur_nom": "Le conseil syndical", "ancien_statut": "ouvert", "nouveau_statut": "en_cours",
           "statut_avant": "ouvert", "peut_modifier": true, "peut_supprimer": true},
          {"id": 2, "ticket_id": 41, "type": "commentaire", "cree_le": "2026-11-09T11:00:00",
           "auteur_nom": "Le conseil syndical",
           "contenu": "<p>Le syndic est prévenu ; le plombier passe <strong>demain matin</strong>.</p>",
           "statut_avant": "en_cours", "peut_modifier": true, "peut_supprimer": true},
          {"id": 3, "ticket_id": 41, "type": "reponse", "cree_le": "2026-11-09T13:00:00",
           "auteur_nom": "Le syndic",
           "contenu": "Intervention confirmée à 9 h. La vanne d'arrêt sera fermée une heure.",
           "statut_avant": "en_cours", "peut_modifier": false, "peut_supprimer": false}
        ]
        """#

    /// Ce que le serveur sert au-dessus du plancher (contrat 1.19.0, #93).
    static let auDessus = [
        AuDessusDuPlancher(
            schema: "TicketEvolutionRead", champs: ["peut_modifier", "peut_supprimer"], contrat: "1.19.0"),
    ]

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "evolutions", schema: "TicketEvolutionRead", json: evolutions)
    ]

    /// Les entrées servies, lues par le type généré.
    static func lues() throws -> [Components.Schemas.TicketEvolutionRead] {
        try Relecture.generee([Components.Schemas.TicketEvolutionRead].self, json: evolutions)
    }

    /// Les types qu'une personne saisit (`TYPES_SAISIS` du serveur) : ce faux serveur en a
    /// besoin pour servir les gestes d'une entrée née pendant la session.
    private static let typesSaisis = ["commentaire", "etat"]

    /// L'Historique de l'affaire `affaire` tel que le serveur le servirait à CE lecteur.
    /// Les entrées de la fixture portent les gestes qu'elle sert à l'administrateur ; une
    /// entrée saisie pendant la session est celle du compte, qui la corrige. Ce faux
    /// serveur referme ensuite ce que le vrai ne sert pas à un autre lecteur : effacer
    /// est à l'administrateur seul, et rien ne s'offre hors du conseil.
    static func servies(_ suites: [SuiteAffaire], de affaire: Int, a lecteur: DroitsOnglet) throws -> [SuiteAffaire] {
        suites
    }
}
#endif
