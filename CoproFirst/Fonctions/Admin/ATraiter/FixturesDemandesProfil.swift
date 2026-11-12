// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Les demandes de profil que l'API simulée sert à « À traiter » — en JSON, à la forme
/// de leurs routes, jugées contre leurs schémas (`DemandeProfilEnAttente`,
/// `DemandeProfilTraitee`).
///
/// Tout est inventé : aucun nom de personne réelle.
enum FixturesDemandesProfil {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /admin/demandes-profil → `[DemandeProfilEnAttente]`.
    static let demandes = #"""
        [
          {"id": 41, "utilisateur_id": 31, "statut_demande": "en_attente", "statut_souhaite": "copropriétaire_bailleur",
           "batiment_id_souhaite": null, "batiment_nom_souhaite": null, "motif": "Je mets mon appartement en location.",
           "motif_refus": null, "traite_le": null, "traite_par_id": null, "cree_le": "2026-11-05T09:30:00",
           "utilisateur_nom": "Sacha Exemple", "utilisateur_email": "sacha@exemple.fr",
           "statut_actuel": "copropriétaire_résident", "batiment_actuel": "Bâtiment A"},
          {"id": 42, "utilisateur_id": 32, "statut_demande": "en_attente", "statut_souhaite": null,
           "batiment_id_souhaite": 2, "batiment_nom_souhaite": "Bâtiment B", "motif": null,
           "motif_refus": null, "traite_le": null, "traite_par_id": null, "cree_le": "2026-11-08T17:10:00",
           "utilisateur_nom": "Morgan Fictif", "utilisateur_email": "morgan@exemple.fr",
           "statut_actuel": "locataire", "batiment_actuel": "Bâtiment A"}
        ]
        """#

    /// POST /admin/demandes-profil/{id}/traiter → `DemandeProfilTraitee` : le statut, et
    /// l'annonce que le serveur compose.
    static let approuvee = #"""
        {"statut": "approuvee", "annonce": {"ton": "success", "texte": "Demande approuvée."}}
        """#
    static let rejetee = #"""
        {"statut": "rejetee", "annonce": {"ton": "success", "texte": "Demande rejetée."}}
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "demandes", schema: "DemandeProfilEnAttente", json: demandes),
        Reponse(nom: "approuvee", schema: "DemandeProfilTraitee", json: approuvee),
        Reponse(nom: "rejetee", schema: "DemandeProfilTraitee", json: rejetee),
    ]

    static func annonce(approuver: Bool) throws -> PhraseAvis {
        PhraseAvis(
            try Relecture.generee(Components.Schemas.DemandeProfilTraitee.self, json: approuver ? approuvee : rejetee)
                .annonce)
    }

    static func lues() throws -> [DemandeProfil] {
        try Relecture.generee([Components.Schemas.DemandeProfilEnAttente].self, json: demandes)
            .map(DemandeProfil.init)
    }
}
#endif
