// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Le fil des messages que l'API simulée sert — en JSON, tel que GET
/// /tickets/{id}/messages le renvoie au compte simulé (`MessageRead` des tickets :
/// `auteur_nom`, `est_auteur`, #138), lu par le type GÉNÉRÉ puis par le MÊME branchement
/// que le service réel (`MessageAffaire(_:)`).
/// `scripts/verifier-fixtures.py` le juge contre le schéma du serveur.
///
/// L'affaire 41 : un message du compte simulé, la réponse du conseil, et une note
/// interne que le serveur ne sert qu'au conseil. Tout est inventé : aucun nom de personne.
enum FixturesMessagesAffaire {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /tickets/41/messages → `[MessageRead]`, dans l'ordre de `cree_le`.
    static let messages = #"""
        [
          {"id": 501, "ticket_id": 41, "auteur_id": 7, "auteur_qualite": null,
           "auteur_nom": "Camille ESSAI", "est_auteur": true,
           "contenu": "<p>Ça goutte encore ce soir, le seau est presque plein.</p>", "interne": false,
           "cree_le": "2026-11-09T19:40:00", "fichiers_urls": []},
          {"id": 502, "ticket_id": 41, "auteur_id": 1, "auteur_qualite": "Le conseil syndical",
           "auteur_nom": "Le conseil syndical", "est_auteur": false,
           "contenu": "<p>Merci, nous le vidons ce soir. Le plombier passe <strong>demain matin</strong>.</p>",
           "interne": false, "cree_le": "2026-11-09T20:05:00", "fichiers_urls": []},
          {"id": 503, "ticket_id": 41, "auteur_id": 1, "auteur_qualite": "Le conseil syndical",
           "auteur_nom": "Le conseil syndical", "est_auteur": false,
           "contenu": "<p>Demander au syndic le devis de la colonne d'eau.</p>", "interne": true,
           "cree_le": "2026-11-09T20:10:00", "fichiers_urls": []}
        ]
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "messages", schema: "app__routers__tickets__messages_schemas__MessageRead", json: messages)
    ]

    /// Les messages de cette affaire que le serveur servirait à ce lecteur : une note
    /// interne au conseil seulement (`lit_les_notes_internes`).
    static func lus(pour affaire: Int, conseil: Bool) throws -> [MessageAffaire] {
        try Relecture.generee([MessageAffaire.Servi].self, json: messages)
            .filter { $0.ticketId == affaire && (conseil || !$0.interne) }
            .map(MessageAffaire.init)
    }
}
#endif
