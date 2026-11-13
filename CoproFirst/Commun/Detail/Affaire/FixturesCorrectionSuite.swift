// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// La réponse du PATCH /tickets/{id}/evolutions/{evol_id} quand l'affaire n'a pas suivi la
/// correction du Suivi (#187, coprofirst#2715) — à la forme du serveur, jugée contre le
/// contrat par `scripts/verifier-fixtures.py`. L'API simulée la sert en y posant ce que
/// SA correction a donné (`ServiceSimule.corrigerSuite`), puis la relit par la même
/// lecture que le service réel (`IssueCorrection.lue`). Tout est inventé.
enum FixturesCorrectionSuite {
    typealias Reponse = FixturesAcces.Reponse

    /// L'entrée 1 de l'affaire 41, corrigée vers « Chez le prestataire » alors qu'une
    /// Suite plus récente a passé l'affaire à « Résolu » : l'affaire reste où elle est, la
    /// réponse le dit et propose l'état.
    static let nonSuivie = #"""
        {"id": 1, "ticket_id": 41, "type": "etat", "cree_le": "2026-11-09T10:00:00",
         "auteur_nom": "Le conseil syndical", "ancien_statut": "ouvert", "nouveau_statut": "chez_prestataire",
         "statut_avant": "ouvert", "nouveau_statut_libelle": "Chez le prestataire",
         "perimetre_precise_libelle": "", "peut_modifier": true, "peut_supprimer": false,
         "affaire_suivie": false,
         "affaire_suivie_libelle": "L'affaire est restée « Résolu » : une Suite plus récente a changé son état depuis.",
         "etat_propose": "chez_prestataire", "etat_propose_libelle": "Chez le prestataire"}
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge.
    static let parSchema: [Reponse] = [
        Reponse(nom: "correctionNonSuivie", schema: "TicketEvolutionRead", json: nonSuivie),
    ]

    /// Ce que le serveur sert au-dessus du plancher (contrat 1.30.0, #187).
    static let auDessus = [
        AuDessusDuPlancher(
            schema: "TicketEvolutionRead",
            champs: ["affaire_suivie", "affaire_suivie_libelle", "etat_propose", "etat_propose_libelle"],
            contrat: "1.30.0"),
    ]

    /// La réponse servie pour CETTE correction : la phrase, l'état proposé et son libellé
    /// que le faux serveur a calculés, posés sur la forme de la fixture.
    static func servie(phrase: String, etatPropose: String?, libelle: String) throws -> Data {
        guard var json = try JSONSerialization.jsonObject(with: Data(nonSuivie.utf8)) as? [String: Any] else {
            throw ErreurService.inattendue(500)
        }
        json["affaire_suivie_libelle"] = phrase
        json["etat_propose"] = etatPropose ?? NSNull()
        json["etat_propose_libelle"] = etatPropose == nil ? "" : libelle
        return try JSONSerialization.data(withJSONObject: json)
    }
}
#endif
