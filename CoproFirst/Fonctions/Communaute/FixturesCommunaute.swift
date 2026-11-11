// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Les réponses que l'API simulée sert pour la Communauté — en JSON, telles que
/// `/idees` et `/annonces` les renvoient, lues par les types GÉNÉRÉS puis par le MÊME
/// branchement que le service réel (`Idee(_:)`, `Annonce(_:)`).
///
/// 🔴 Pourquoi du JSON (bogue du 06/11/2026) : la simulation construisait des `Idee`
/// à la main ; le service réel, lui, relisait les réponses typées par `Relecture`, qui
/// réencodait leurs dates en nombre. Les tests étaient verts, l'iPhone affichait
/// « Impossible d'afficher les idées ». `scripts/verifier-fixtures.py` confronte
/// chaque réponse déclarée dans `parSchema` au schéma de sa route.
///
/// Tout est inventé : aucun nom de personne.
enum FixturesCommunaute {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /idees → `[IdeeRead]`.
    static let idees = #"""
        [
          {"id": 3, "titre": "Un composteur partagé dans le jardin",
           "description": "<p>Pour réduire nos déchets et nourrir les massifs.</p>", "auteur_id": 7,
           "statut": "retenue", "cree_le": "2026-10-25T09:30:00", "nb_votes": 18, "mon_vote": true,
           "archivee": false, "nb_reponses": 1,
           "reponses": [
             {"id": 1, "auteur_id": 5, "contenu": "Excellente idée, je veux bien m'en occuper.",
              "cree_le": "2026-10-26T18:00:00", "auteur_nom": "Voisin du bât. A", "auteur_batiment": "Bât. A",
              "auteur_role": "Résident", "est_cs": false}
           ]},
          {"id": 5, "titre": "Une boîte à livres dans le hall A",
           "description": "<p>Une étagère où chacun dépose et emprunte.</p>", "auteur_id": 4,
           "statut": "ouverte", "cree_le": "2026-11-05T08:00:00", "nb_votes": 9, "mon_vote": false,
           "archivee": false, "nb_reponses": 1,
           "reponses": [
             {"id": 2, "auteur_id": 1, "contenu": "Le conseil syndical en parlera jeudi.",
              "cree_le": "2026-11-05T19:00:00", "auteur_nom": "Conseil syndical", "auteur_batiment": "Bât. A",
              "auteur_role": "Conseil syndical", "est_cs": true}
           ]},
          {"id": 1, "titre": "Repeindre la cage d'escalier", "description": "<p>Elle en a bien besoin.</p>",
           "auteur_id": 2, "statut": "realisee", "cree_le": "2026-04-20T10:00:00", "nb_votes": 31,
           "mon_vote": false, "archivee": true, "nb_reponses": 0, "reponses": []}
        ]
        """#

    /// GET /annonces → `[AnnonceRead]`.
    static let annonces = #"""
        [
          {"id": 21, "titre": "Lave-linge presque neuf",
           "description": "<p>Huit kilos, deux ans, factures à l'appui.</p>",
           "type_annonce": "vente", "categorie": "electromenager", "prix": 180, "negotiable": true, "photos": [],
           "statut": "en_cours", "auteur_id": 12, "auteur_prenom": "Voisine du 2ᵉ",
           "auteur_email": "voisine@exemple.fr", "est_auteur": false, "peut_modifier": false,
           "peut_supprimer": true, "archivee": false,
           "cree_le": "2026-11-04T10:00:00", "nb_reponses": 1,
           "reponses": [
             {"id": 3, "auteur_id": 5, "contenu": "Est-il encore disponible samedi ?",
              "cree_le": "2026-11-05T18:00:00", "auteur_nom": "Voisin du bât. A", "auteur_batiment": "Bât. A",
              "auteur_role": "Résident", "est_cs": false}
           ]},
          {"id": 22, "titre": "Plantes vertes à donner", "description": "<p>Un ficus et deux monsteras.</p>",
           "type_annonce": "don", "categorie": "divers", "negotiable": false, "photos": [], "statut": "reserve",
           "auteur_id": 7, "auteur_prenom": "Moi", "est_auteur": true, "peut_modifier": true,
           "peut_supprimer": true, "archivee": false,
           "cree_le": "2026-10-31T15:00:00", "nb_reponses": 0, "reponses": []},
          {"id": 23, "titre": "Cherche place de parking", "description": "<p>Au sous-sol, pour une citadine.</p>",
           "type_annonce": "recherche", "categorie": "parking_cave", "negotiable": false, "photos": [],
           "statut": "en_cours", "auteur_id": 14, "auteur_prenom": "Voisin du 5ᵉ", "est_auteur": false,
           "peut_modifier": false, "peut_supprimer": true, "archivee": false, "cree_le": "2026-10-22T11:00:00",
           "nb_reponses": 0, "reponses": []}
        ]
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "idees", schema: "IdeeRead", json: idees),
        Reponse(nom: "annonces", schema: "AnnonceRead", json: annonces),
    ]

    // MARK: - Lues comme le client généré les lit, branchées comme le service réel

    static func ideesLues() throws -> [Idee] {
        try Relecture.generee([Components.Schemas.IdeeRead].self, json: idees).map(Idee.init)
    }

    static func annoncesLues() throws -> [Annonce] {
        try Relecture.generee([Components.Schemas.AnnonceRead].self, json: annonces).map(Annonce.init)
    }
}
#endif
