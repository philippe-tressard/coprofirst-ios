// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Les réponses que l'API simulée sert pour les Délégations — en JSON, à la forme de
/// leurs routes, lues par les types GÉNÉRÉS puis par le MÊME branchement que le service
/// réel (`Delegation(_:)`, `ResidentDelegable(_:)`). `scripts/verifier-fixtures.py` les
/// juge contre le contrat. Le compte qui lit est le n° 7 (`ServiceSimule.moiDelegations`) :
/// les gestes servis (`peut_accepter`, `peut_revoquer`) sont les siens.
///
/// Tout est inventé : aucun nom de personne réelle.
enum FixturesDelegations {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /delegations → `[DelegationRead]`.
    static let delegations = #"""
        [
          {"id": 12, "mandant_id": 3, "mandant_nom": "Lucie Exemple", "aidant_id": 7, "aidant_nom": "Camille Essai",
           "statut": "en_attente", "motif": "Assistance pendant une convalescence", "date_debut": "2026-11-06",
           "date_fin": "2027-02-04", "cree_le": "2026-11-06T09:00:00", "revoque_le": null,
           "peut_accepter": true, "peut_revoquer": true},
          {"id": 8, "mandant_id": 4, "mandant_nom": "Marc Démo", "aidant_id": 3, "aidant_nom": "Lucie Exemple",
           "statut": "active", "motif": "Assistance personne âgée", "date_debut": "2026-07-11", "date_fin": null,
           "cree_le": "2026-07-11T10:30:00", "revoque_le": null, "peut_accepter": false, "peut_revoquer": true},
          {"id": 5, "mandant_id": 9, "mandant_nom": "Paul Fictif", "aidant_id": 4, "aidant_nom": "Marc Démo",
           "statut": "revoquee", "motif": "", "date_debut": "2025-10-04", "date_fin": "2026-10-09",
           "cree_le": "2025-10-04T08:00:00", "revoque_le": "2026-10-09T17:45:00",
           "peut_accepter": false, "peut_revoquer": false}
        ]
        """#

    /// GET /admin/utilisateurs → `[UtilisateurAdminRead]`, les champs que le contrat exige.
    static let utilisateurs = #"""
        [
          {"id": 3, "prenom": "Lucie", "nom": "Exemple", "email": "lucie@exemple.fr", "actif": true,
           "role": "propriétaire", "statut": "copropriétaire_résident", "cree_le": "2025-03-02T10:00:00",
           "onboarding_complete": true, "onboarding_etape": 4, "preferences_notifications": "{}",
           "has_lots": true, "has_bail": false, "has_vigik": true, "has_tc": false,
           "etiquettes": {"loti": "oui", "bail": "non", "vigik": "oui", "tc": "non"}},
          {"id": 4, "prenom": "Marc", "nom": "Démo", "email": "marc@exemple.fr", "actif": true,
           "role": "propriétaire", "statut": "copropriétaire_résident", "cree_le": "2025-04-12T10:00:00",
           "onboarding_complete": true, "onboarding_etape": 4, "preferences_notifications": "{}",
           "has_lots": true, "has_bail": false, "has_vigik": false, "has_tc": false,
           "etiquettes": {"loti": "oui", "bail": "non", "vigik": "non", "tc": "non"}},
          {"id": 7, "prenom": "Camille", "nom": "Essai", "email": "camille@exemple.fr", "actif": true,
           "role": "conseil_syndical", "statut": "copropriétaire_résident", "cree_le": "2024-09-01T10:00:00",
           "onboarding_complete": true, "onboarding_etape": 4, "preferences_notifications": "{}",
           "has_lots": true, "has_bail": false, "has_vigik": true, "has_tc": true,
           "etiquettes": {"loti": "oui", "bail": "non", "vigik": "oui", "tc": "oui"}},
          {"id": 9, "prenom": "Paul", "nom": "Fictif", "email": "paul@exemple.fr", "actif": false,
           "role": "résident", "statut": "locataire", "cree_le": "2023-01-15T10:00:00",
           "onboarding_complete": false, "onboarding_etape": 1, "preferences_notifications": "{}",
           "has_lots": false, "has_bail": true, "has_vigik": false, "has_tc": false,
           "etiquettes": {"loti": "non", "bail": "oui", "vigik": "non", "tc": "non"}}
        ]
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "delegations", schema: "DelegationRead", json: delegations),
        Reponse(nom: "utilisateurs", schema: "UtilisateurAdminRead", json: utilisateurs),
    ]

    // MARK: - Lues comme le client généré les lit, branchées comme le service réel

    static func delegationsLues() throws -> [Delegation] {
        try Relecture.generee([Components.Schemas.DelegationRead].self, json: delegations).map(Delegation.init)
    }

    static func residentsLus() throws -> [ResidentDelegable] {
        try Relecture.generee([Components.Schemas.UtilisateurAdminRead].self, json: utilisateurs)
            .map(ResidentDelegable.init)
    }
}
#endif
