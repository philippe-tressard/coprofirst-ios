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
/// Les droits sont ceux d'un RÉSIDENT : l'auteur de l'affaire 41, engagée chez le syndic, garde le crayon (`peut_corriger`) sans plus
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
           "peut_repondre": true, "peut_modifier": false, "peut_corriger": true,
           "frequence_libelle": "", "suivi_actualite_libelle": ""},
          {"id": 12, "numero": "A-0012", "titre": "Coupure d'eau jeudi de 9 h à 12 h",
           "description": "Le remplacement d'une vanne dans la cave du bâtiment A impose de couper l'eau froide et l'eau chaude jeudi matin, de 9 h à 12 h. Pensez à faire une réserve.",
           "categorie": "actualite", "categorie_libelle": "Actualité", "statut": "publie",
           "statut_libelle": "Publiée", "priorite": "normale", "urgente": false, "close": false,
           "colonne_kanban": null, "nouveau": false, "nom_proprietaire": "",
           "cree_le": "2026-11-10T08:00:00", "auteur_nom": "Le conseil syndical",
           "perimetre_cible": ["bat_a"], "perimetre_libelle": "Bâtiment A",
           "suivi_actualite": "ouvert", "suivi_actualite_libelle": "Ouvert", "frequence_libelle": ""},
          {"id": 38, "numero": "A-0038", "titre": "Ravalement de la façade côté rue",
           "description": "Le devis retenu en assemblée générale sera présenté au conseil syndical.",
           "categorie": "etude_travaux", "categorie_libelle": "Étude & travaux", "statut": "en_ag",
           "statut_libelle": "À l’AG", "priorite": "normale", "urgente": false, "close": false,
           "colonne_kanban": "ag", "nouveau": false, "nom_proprietaire": "",
           "cree_le": "2026-11-08T10:00:00", "auteur_nom": "Le conseil syndical",
           "perimetre_cible": ["bat_a"], "perimetre_libelle": "Bâtiment A", "peut_repondre": true,
           "frequence_libelle": "", "suivi_actualite_libelle": ""},
          {"id": 31, "numero": "A-0031", "titre": "Portail du garage remis en service",
           "description": "La télécommande fonctionne de nouveau après le remplacement de la carte électronique.",
           "categorie": "panne", "categorie_libelle": "Panne", "statut": "résolu",
           "statut_libelle": "Résolu", "priorite": "normale", "urgente": false, "close": true,
           "colonne_kanban": "termine", "nouveau": false, "nom_proprietaire": "",
           "cree_le": "2026-11-06T18:00:00", "auteur_nom": "Le conseil syndical",
           "perimetre_cible": ["parking"], "perimetre_libelle": "Parking",
           "frequence_libelle": "", "suivi_actualite_libelle": ""},
          {"id": 44, "numero": "A-0044", "titre": "Ramonage des conduits de cheminée",
           "description": "Le ramoneur passe dans les caves du bâtiment B ; laissez l'accès aux conduits.",
           "categorie": "entretien", "categorie_libelle": "Entretien", "statut": "en_cours",
           "statut_libelle": "Chez le syndic", "priorite": "normale", "urgente": false, "close": false,
           "colonne_kanban": "syndic", "nouveau": false, "nom_proprietaire": "",
           "cree_le": "2026-11-11T00:00:00", "auteur_nom": "Le conseil syndical",
           "perimetre_cible": ["bat_b"], "perimetre_libelle": "Bâtiment B",
           "prestataire_nom": "Ramonage Exemple (fictif)", "frequence_type": "fois_par_an",
           "frequence_valeur": 1, "frequence_libelle": "↺ 1×/an", "suivi_actualite_libelle": ""},
          {"id": 45, "numero": "A-0045", "titre": "Contrôle annuel de l'ascenseur",
           "description": "Le contrôleur est passé ; son rapport sera transmis au conseil syndical.",
           "categorie": "entretien", "categorie_libelle": "Entretien", "statut": "en_cours",
           "statut_libelle": "Chez le syndic", "priorite": "normale", "urgente": false, "close": false,
           "colonne_kanban": "syndic", "nouveau": false, "nom_proprietaire": "",
           "cree_le": "2026-11-10T13:00:00", "auteur_nom": "Le conseil syndical",
           "perimetre_cible": ["bat_b"], "perimetre_libelle": "Bâtiment B",
           "prestataire_nom": "Ascenseurs du Parc (fictif)", "frequence_type": "fois_par_an",
           "frequence_valeur": 1, "frequence_libelle": "↺ 1×/an", "suivi_actualite_libelle": "", "contrat_id": 1,
           "contrat": {"id": 1, "libelle": "Maintenance des deux ascenseurs", "numero_contrat": "ASC-2024-118",
                       "frequence_type": "mois", "frequence_valeur": 1, "frequence_libelle": "↺ Mensuel"}}
        ]
        """#
    // swiftlint:enable line_length

    /// GET /tickets/41/evolutions → `[TicketEvolutionRead]` : l'Historique de l'affaire 41,
    /// servi à un résident — aucune entrée qu'il corrige ou efface (`peut_modifier`,
    /// `peut_supprimer`, #93). Le conseil et l'administrateur reçoivent leurs gestes du
    /// faux serveur (`ServiceSimule.servie`).
    static let evolutions = #"""
        [
          {"id": 1, "ticket_id": 41, "type": "etat", "cree_le": "2026-11-09T10:00:00",
           "auteur_nom": "Le conseil syndical", "ancien_statut": "ouvert", "nouveau_statut": "en_cours",
           "nouveau_statut_libelle": "Chez le syndic", "perimetre_precise_libelle": "",
           "statut_avant": "ouvert", "peut_modifier": false, "peut_supprimer": false},
          {"id": 2, "ticket_id": 41, "type": "commentaire", "cree_le": "2026-11-09T11:00:00",
           "auteur_nom": "Le conseil syndical",
           "contenu": "<p>Le syndic est prévenu ; le plombier passe <strong>demain matin</strong>.</p>",
           "nouveau_statut_libelle": "", "perimetre_precise_libelle": "",
           "statut_avant": "en_cours", "peut_modifier": false, "peut_supprimer": false},
          {"id": 3, "ticket_id": 41, "type": "reponse", "cree_le": "2026-11-09T13:00:00",
           "auteur_nom": "Le syndic",
           "contenu": "Intervention confirmée à 9 h. La vanne d'arrêt sera fermée une heure.",
           "fichiers_urls": ["/uploads/tickets/41-vanne.jpg",
                             "/uploads/tickets/0123456789abcdef0123456789abcdef_Devis%20plombier.pdf"],
           "nouveau_statut_libelle": "", "perimetre_precise_libelle": "",
           "statut_avant": "en_cours", "peut_modifier": false, "peut_supprimer": false}
        ]
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "affaires", schema: "TicketRead", json: affaires),
        Reponse(nom: "evolutions", schema: "TicketEvolutionRead", json: evolutions),
    ]

    /// L'affaire `id` telle que le service réel la lirait : son `TicketRead`, puis ses
    /// évolutions.
    static func lue(_ id: Int) throws -> DetailAffaire? {
        let tickets = try Relecture.generee([Components.Schemas.TicketRead].self, json: affaires)
        guard let ticket = tickets.first(where: { $0.id == id }) else { return nil }
        let suites = try Relecture.generee([Components.Schemas.TicketEvolutionRead].self, json: evolutions)
        return DetailAffaire.lue(ticket, evolutions: suites.filter { $0.ticketId == id })
    }
}
#endif
