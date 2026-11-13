// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Les affiches que l'API simulée sert — le JSON de `GET /annonces-hall`, lu par le type
/// GÉNÉRÉ puis par le MÊME branchement que le service réel (`AnnonceHall(_:)`), et jugé
/// contre le contrat par `scripts/verifier-fixtures.py`. Les gestes servis sont ceux d'un
/// administrateur : la n° 3, rangée par le temps, ne se restaure pas (coprofirst#515).
///
/// Tout est inventé : aucun nom de personne réelle.
enum FixturesAnnoncesHall {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /annonces-hall → `[AnnonceHallRead]` (en cours et archivées ensemble).
    static let affiches = #"""
        [
          {"id": 7, "titre": "Coupure d'eau jeudi matin",
           "message": "<p>L'eau sera coupée <strong>jeudi de 8 h à 12 h</strong> pour le remplacement d'une vanne.</p>",
           "apercu": "L'eau sera coupée jeudi de 8 h à 12 h pour le remplacement d'une vanne.",
           "assiste_ia": false, "perimetre_cible": ["bat_a"], "perimetre_label": "Bâtiment A",
           "perimetre_libelle": "Bât. A",
           "format_demande": "auto", "format_effectif": "A5", "format_label": "A5", "images": [],
           "destinataires": ["Lucie Exemple", "Marc Démo"], "envoye_le": "2026-11-06T09:00:00",
           "archivee": false, "archivee_manuellement": false, "ticket_id": null, "pdf_nom": "annonce-7.pdf",
           "taille_octets": 48213, "cree_le": "2026-11-06T09:00:00", "auteur_nom": "Camille Essai",
           "peut_archiver": true, "peut_restaurer": false, "peut_supprimer": true},
          {"id": 6, "titre": "Fête des voisins",
           "message": "<p>Rendez-vous dans le jardin le 6 juin à 19 h. Chacun apporte un plat !</p>",
           "apercu": "Rendez-vous dans le jardin le 6 juin à 19 h. Chacun apporte un plat !",
           "assiste_ia": true, "perimetre_cible": [], "perimetre_label": "Toute la copropriété",
           "perimetre_libelle": "",
           "format_demande": "A4", "format_effectif": "A4", "format_label": "A4", "images": [],
           "destinataires": [], "envoye_le": null, "archivee": false, "archivee_manuellement": false,
           "ticket_id": 31, "pdf_nom": "annonce-6.pdf", "taille_octets": 51877, "cree_le": "2026-10-30T18:30:00",
           "auteur_nom": "Camille Essai", "peut_archiver": true, "peut_restaurer": false, "peut_supprimer": true},
          {"id": 4, "titre": "Ramassage des encombrants",
           "message": "<p>Les encombrants seront enlevés le 2 octobre au matin.</p>",
           "apercu": "Les encombrants seront enlevés le 2 octobre au matin.",
           "assiste_ia": false, "perimetre_cible": [], "perimetre_label": "Toute la copropriété",
           "perimetre_libelle": "",
           "format_demande": "A5", "format_effectif": "A5", "format_label": "A5", "images": [],
           "destinataires": ["Lucie Exemple"], "envoye_le": "2026-09-25T08:00:00", "archivee": true,
           "archivee_manuellement": true, "ticket_id": null, "pdf_nom": "annonce-4.pdf", "taille_octets": 40112,
           "cree_le": "2026-09-25T08:00:00", "auteur_nom": "Camille Essai",
           "peut_archiver": false, "peut_restaurer": true, "peut_supprimer": true},
          {"id": 3, "titre": "Nettoyage du parking",
           "message": "<p>Merci de libérer vos places le 12 mars au matin.</p>",
           "apercu": "Merci de libérer vos places le 12 mars au matin.", "assiste_ia": false,
           "perimetre_cible": ["parking"], "perimetre_label": "Parking", "perimetre_libelle": "Parking",
           "format_demande": "A6",
           "format_effectif": "A6", "format_label": "A6", "images": [], "destinataires": ["Lucie Exemple", "Marc Démo"],
           "envoye_le": "2026-03-05T10:00:00", "archivee": true, "archivee_manuellement": false, "ticket_id": null,
           "pdf_nom": "annonce-3.pdf", "taille_octets": 39004, "cree_le": "2026-03-05T10:00:00",
           "auteur_nom": "Camille Essai", "peut_archiver": false, "peut_restaurer": false, "peut_supprimer": true}
        ]
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "affiches", schema: "AnnonceHallRead", json: affiches)
    ]

    /// Lues comme le client généré les lit, branchées comme le service réel.
    static func affichesLues() throws -> [AnnonceHall] {
        try Relecture.generee([Components.Schemas.AnnonceHallRead].self, json: affiches).map(AnnonceHall.init)
    }
}
#endif
