// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Les affaires que l'API simulée sert à leur fiche — en JSON, tel que GET /tickets/{id}
/// et GET /tickets/{id}/evolutions les renvoient, lues par les types GÉNÉRÉS puis par le
/// MÊME branchement que le service réel (`DetailAffaire.lue`), et jugées contre le
/// contrat par `scripts/verifier-fixtures.py`.
///
/// Les droits sont ceux d'un RÉSIDENT, à la forme du serveur v3.88.1 : l'auteur de
/// l'affaire 41, engagée chez le syndic, garde le crayon (`peut_corriger`) sans plus
/// corriger le contenu (`peut_modifier`, #127). Le conseil syndical reçoit les siens de
/// `ServiceSimule.affaires(_:conseil:)`. Tout est inventé : aucun nom de personne.
enum FixturesDetailAffaire {
    typealias Reponse = FixturesAcces.Reponse

    // swiftlint:disable line_length
    /// GET /tickets/{id} → `TicketRead`, une affaire par identifiant. Une chaîne JSON ne
    /// passe pas à la ligne : la description mise en forme de l'affaire 41 (gras, liste,
    /// lien — ce que `TexteRiche` rend) tient sur une seule.
    static let affaires = #"""
        [
          {"id": 41, "numero": "A-0041", "titre": "Fuite d'eau au plafond du parking",
           "description": "<p>Une infiltration goutte au niveau -1, place 12. Le sol est <strong>glissant</strong>&nbsp;: un seau a été posé en attendant le plombier.</p><ol><li><p>Merci de contourner la zone, et de ne pas déplacer le seau posé sous la fuite ;</p></li><li><p>photos jointes ci-dessous.</p></li></ol><p>Le contrat d'entretien : <a href=\"https://www.example.org/contrat\">consulter</a>.</p>",
           "categorie": "sinistre", "categorie_libelle": "Sinistre", "statut": "en_cours",
           "statut_libelle": "Chez le syndic", "priorite": "haute", "urgente": true, "close": false,
           "colonne_kanban": "syndic", "nouveau": false, "nom_proprietaire": "",
           "cree_le": "2026-11-09T09:00:00", "auteur_nom": "Un résident du bâtiment A",
           "perimetre_cible": ["parking"], "perimetre_libelle": "Parking",
           "photos_urls": ["/uploads/tickets/41-1.jpg", "/uploads/tickets/41-2.jpg",
                           "/uploads/tickets/41-3.jpg", "/uploads/tickets/41-4.jpg"],
           "fichiers_urls": ["/uploads/tickets/0123456789abcdef0123456789abcdef_Devis%20plombier.pdf",
                             "/uploads/tickets/41-consignes.txt"],
           "peut_repondre": true, "peut_modifier": false, "peut_corriger": true},
          {"id": 12, "numero": "A-0012", "titre": "Coupure d'eau jeudi de 9 h à 12 h",
           "description": "Le remplacement d'une vanne dans la cave du bâtiment A impose de couper l'eau froide et l'eau chaude jeudi matin, de 9 h à 12 h. Pensez à faire une réserve.",
           "categorie": "actualite", "categorie_libelle": "Actualité", "statut": "publie",
           "statut_libelle": "Publiée", "priorite": "normale", "urgente": false, "close": false,
           "colonne_kanban": null, "nouveau": false, "nom_proprietaire": "",
           "cree_le": "2026-11-10T08:00:00", "auteur_nom": "Le conseil syndical",
           "perimetre_cible": ["bat_a"], "perimetre_libelle": "Bâtiment A",
           "suivi_actualite": "ouvert", "suivi_actualite_libelle": "Ouvert"},
          {"id": 38, "numero": "A-0038", "titre": "Ravalement de la façade côté rue",
           "description": "Le devis retenu en assemblée générale sera présenté au conseil syndical.",
           "categorie": "etude_travaux", "categorie_libelle": "Étude & travaux", "statut": "en_ag",
           "statut_libelle": "À l’AG", "priorite": "normale", "urgente": false, "close": false,
           "colonne_kanban": "ag", "nouveau": false, "nom_proprietaire": "",
           "cree_le": "2026-11-08T10:00:00", "auteur_nom": "Le conseil syndical",
           "perimetre_cible": ["bat_a"], "perimetre_libelle": "Bâtiment A", "peut_repondre": true},
          {"id": 31, "numero": "A-0031", "titre": "Portail du garage remis en service",
           "description": "La télécommande fonctionne de nouveau après le remplacement de la carte électronique.",
           "categorie": "panne", "categorie_libelle": "Panne", "statut": "résolu",
           "statut_libelle": "Résolu", "priorite": "normale", "urgente": false, "close": true,
           "colonne_kanban": "termine", "nouveau": false, "nom_proprietaire": "",
           "cree_le": "2026-11-06T18:00:00", "auteur_nom": "Le conseil syndical",
           "perimetre_cible": ["parking"], "perimetre_libelle": "Parking"},
          {"id": 44, "numero": "A-0044", "titre": "Ramonage des conduits de cheminée",
           "description": "Le ramoneur passe dans les caves du bâtiment B ; laissez l'accès aux conduits.",
           "categorie": "entretien", "categorie_libelle": "Entretien", "statut": "en_cours",
           "statut_libelle": "Chez le syndic", "priorite": "normale", "urgente": false, "close": false,
           "colonne_kanban": "syndic", "nouveau": false, "nom_proprietaire": "",
           "cree_le": "2026-11-11T00:00:00", "auteur_nom": "Le conseil syndical",
           "perimetre_cible": ["bat_b"], "perimetre_libelle": "Bâtiment B",
           "prestataire_nom": "Ramonage Exemple (fictif)", "frequence_type": "fois_par_an",
           "frequence_valeur": 1, "frequence_libelle": "↺ 1×/an"},
          {"id": 45, "numero": "A-0045", "titre": "Contrôle annuel de l'ascenseur",
           "description": "Le contrôleur est passé ; son rapport sera transmis au conseil syndical.",
           "categorie": "entretien", "categorie_libelle": "Entretien", "statut": "en_cours",
           "statut_libelle": "Chez le syndic", "priorite": "normale", "urgente": false, "close": false,
           "colonne_kanban": "syndic", "nouveau": false, "nom_proprietaire": "",
           "cree_le": "2026-11-10T13:00:00", "auteur_nom": "Le conseil syndical",
           "perimetre_cible": ["bat_b"], "perimetre_libelle": "Bâtiment B",
           "prestataire_nom": "Ascenseurs du Parc (fictif)", "frequence_type": "fois_par_an",
           "frequence_valeur": 1, "frequence_libelle": "↺ 1×/an", "contrat_id": 1,
           "contrat": {"id": 1, "libelle": "Maintenance des deux ascenseurs", "numero_contrat": "ASC-2024-118",
                       "frequence_type": "mois", "frequence_valeur": 1, "frequence_libelle": "↺ Mensuel"}}
        ]
        """#
    // swiftlint:enable line_length

    /// GET /tickets/41/evolutions → `[TicketEvolutionRead]` : l'Historique de l'affaire 41.
    static let evolutions = #"""
        [
          {"id": 1, "ticket_id": 41, "type": "etat", "cree_le": "2026-11-09T10:00:00",
           "auteur_nom": "Le conseil syndical", "ancien_statut": "ouvert", "nouveau_statut": "en_cours",
           "nouveau_statut_libelle": "Chez le syndic"},
          {"id": 2, "ticket_id": 41, "type": "commentaire", "cree_le": "2026-11-09T11:00:00",
           "auteur_nom": "Le conseil syndical",
           "contenu": "<p>Le syndic est prévenu ; le plombier passe <strong>demain matin</strong>.</p>",
           "nouveau_statut_libelle": ""},
          {"id": 3, "ticket_id": 41, "type": "reponse", "cree_le": "2026-11-09T13:00:00",
           "auteur_nom": "Le syndic",
           "contenu": "Intervention confirmée à 9 h. La vanne d'arrêt sera fermée une heure.",
           "fichiers_urls": ["/uploads/tickets/41-vanne.jpg",
                             "/uploads/tickets/0123456789abcdef0123456789abcdef_Devis%20plombier.pdf"],
           "nouveau_statut_libelle": ""},
          {"id": 4, "ticket_id": 31, "type": "etat", "cree_le": "2026-11-07T09:30:00",
           "auteur_nom": "Le conseil syndical", "ancien_statut": "ouvert", "nouveau_statut": "résolu",
           "nouveau_statut_libelle": "Résolu",
           "contenu": "La carte électronique du portail a été remplacée."},
          {"id": 5, "ticket_id": 31, "type": "synthese", "cree_le": "2026-11-08T10:00:00",
           "auteur_nom": "Le conseil syndical", "nouveau_statut_libelle": ""}
        ]
        """#

    /// Ce que le serveur sert au-dessus du plancher (contrats 1.20.0 et 1.21.0, #125, #127).
    static let auDessus = [
        AuDessusDuPlancher(
            schema: "TicketRead", champs: ["peut_corriger", "suivi_actualite_libelle", "frequence_libelle"],
            contrat: "1.21.0"),
        AuDessusDuPlancher(schema: "ContratDeLAffaire", champs: ["frequence_libelle"], contrat: "1.20.0"),
        AuDessusDuPlancher(schema: "TicketEvolutionRead", champs: ["nouveau_statut_libelle"], contrat: "1.21.0"),
    ]

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "affaires", schema: "TicketRead", json: affaires),
        Reponse(nom: "evolutions", schema: "TicketEvolutionRead", json: evolutions),
    ]

    /// L'affaire `id` telle que le service réel la lirait : son corps servi seul, puis
    /// ses évolutions.
    static func lue(_ id: Int) throws -> DetailAffaire? {
        let objets = try JSONSerialization.jsonObject(with: Data(affaires.utf8)) as? [[String: Any]] ?? []
        guard let objet = objets.first(where: { $0["id"] as? Int == id }) else { return nil }
        let corps = try JSONSerialization.data(withJSONObject: objet)
        guard let texte = String(bytes: corps, encoding: .utf8) else { return nil }
        let ticket = try Relecture.generee(Components.Schemas.TicketRead.self, json: texte)
        let suites = try Relecture.generee([Components.Schemas.TicketEvolutionRead].self, json: evolutions)
        return DetailAffaire.lue(
            ticket, corps: corps, evolutions: suites.filter { $0.ticketId == id },
            corpsEvolutions: Data(evolutions.utf8))
    }
}
#endif
