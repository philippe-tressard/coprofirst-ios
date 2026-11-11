// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Le relevé que l'API simulée sert à Reporting › Renouvellements — le JSON de
/// `GET /reporting/renouvellements`, lu par le type GÉNÉRÉ puis par le MÊME branchement
/// que le service réel, et jugé contre le contrat par `scripts/verifier-fixtures.py`.
///
/// Tout est inventé : des prestataires qui n'existent pas.
enum FixturesRenouvellements {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /reporting/renouvellements → `ReleveRenouvellements`.
    static let releve = #"""
        {"annee": 2026, "preavis_mois": 3,
         "compteurs": {"contrats_en_preavis": 1, "echeances_contrats_annee": 2, "audits_a_planifier": 2},
         "contrats": [
           {"id": 11, "libelle": "Entretien des ascenseurs", "prestataire_id": 4,
            "prestataire_nom": "Ascenseurs Exemple",
            "type_equipement": "ascenseur", "copropriete_id": 1, "actif": true, "numero_contrat": "ASC-2023-07",
            "date_debut": "2023-12-01", "date_fin": "2026-11-30", "date_preavis": "2026-08-31",
            "note_moyenne": 2.5, "nb_notations": 4, "echeance_dans_l_annee": true, "urgence_echeance": "preavis",
            "reconduit": false},
           {"id": 12, "libelle": "Nettoyage des parties communes", "prestataire_id": 5,
            "prestataire_nom": "Propreté Démo", "type_equipement": "nettoyage", "copropriete_id": 1, "actif": true,
            "date_debut": "2024-12-31", "date_fin": "2026-12-31", "date_preavis": "2026-09-30", "note_moyenne": 4.0,
            "nb_notations": 6, "echeance_dans_l_annee": true, "urgence_echeance": "annee", "reconduit": true},
           {"id": 13, "libelle": "Entretien des espaces verts", "prestataire_id": 6,
            "prestataire_nom": "Jardins Fictifs",
            "type_equipement": "espaces_verts", "copropriete_id": 1, "actif": true, "date_debut": "2025-04-01",
            "date_fin": "2028-03-31", "date_preavis": "2027-12-31", "note_moyenne": 4.5, "nb_notations": 2,
            "echeance_dans_l_annee": false, "urgence_echeance": "futur", "reconduit": false},
           {"id": 14, "libelle": "Contrôle des extincteurs", "prestataire_id": 7, "prestataire_nom": "Sécurité Modèle",
            "type_equipement": "incendie", "copropriete_id": 1, "actif": true, "date_debut": "2025-01-15",
            "date_fin": null, "date_preavis": null, "note_moyenne": null, "nb_notations": 0,
            "echeance_dans_l_annee": false, "urgence_echeance": null, "reconduit": false}
         ],
         "diagnostics": [
           {"id": 2, "nom": "Diagnostic technique global", "code": "DTG", "ordre": 2, "frequence": "10 ans",
            "texte_legislatif": "Article L731-1 du CCH", "permanent": false, "dernier_rapport_le": "2016-03-10",
            "prochaine_echeance": "2026-03-10", "urgence_echeance": "depasse"},
           {"id": 5, "nom": "Contrôle des ascenseurs", "code": "ASC", "ordre": 5, "frequence": "5 ans",
            "texte_legislatif": "Article R134-11 du CCH", "permanent": false, "dernier_rapport_le": "2021-12-02",
            "prochaine_echeance": "2026-12-02", "urgence_echeance": "annee"},
           {"id": 7, "nom": "Diagnostic de performance énergétique", "code": "DPE", "ordre": 7, "frequence": "10 ans",
            "texte_legislatif": "Article L126-31 du CCH", "permanent": false, "dernier_rapport_le": "2022-05-18",
            "prochaine_echeance": "2032-05-18", "urgence_echeance": "futur"},
           {"id": 1, "nom": "Diagnostic amiante (DTA)", "code": "DTA", "ordre": 1, "frequence": null,
            "texte_legislatif": "Article R1334-29-5 du CSP", "permanent": true, "dernier_rapport_le": "2005-09-01",
            "prochaine_echeance": null}
         ]}
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "releve", schema: "ReleveRenouvellements", json: releve)
    ]

    /// Lu comme le client généré le lit, branché comme le service réel.
    static func releveLu() throws -> Renouvellements {
        Renouvellements(try Relecture.generee(Components.Schemas.ReleveRenouvellements.self, json: releve))
    }
}
#endif
