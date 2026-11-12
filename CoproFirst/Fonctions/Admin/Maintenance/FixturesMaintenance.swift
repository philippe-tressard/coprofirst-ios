// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Ce que l'API simulée sert à « Maintenance » — en JSON, à la forme des routes : la
/// santé et le dernier export, chacun jugé contre son schéma.
///
/// Tout est inventé : les nœuds s'appellent « nœud-a » et « nœud-b », aucune adresse,
/// aucun nom de machine réel.
enum FixturesMaintenance {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /admin/maintenance/sante.
    static let sante = #"""
        {
         "taches": [
          {"tache": "maintenance", "noeud": "nœud-a", "noeuds": [], "noeud_enregistre": true, "portee": "applicative",
           "statut": "ok", "derniere": "2026-11-09T03:12:00", "retard_heures": 27.0, "periodicite_heures": 192,
           "noeud_en_retard": null, "statut_en_retard": null},
          {"tache": "reliability", "noeud": "nœud-a", "noeuds": [], "noeud_enregistre": true, "portee": "applicative",
           "statut": "vigilance", "derniere": "2026-11-10T05:00:00", "retard_heures": 1.5, "periodicite_heures": 24,
           "noeud_en_retard": null, "statut_en_retard": null},
          {"tache": "bascule", "noeud": "nœud-a", "noeuds": [], "noeud_enregistre": true, "portee": "applicative",
           "statut": "ok", "derniere": "2026-11-10T02:30:00", "retard_heures": 4.0, "periodicite_heures": 30,
           "noeud_en_retard": "nœud-b", "statut_en_retard": "pas_actif"},
          {"tache": "export_hors_site", "noeud": null, "noeuds": [], "noeud_enregistre": false,
           "statut": "manquante", "derniere": "2026-09-30T19:00:00", "retard_heures": 984.0, "periodicite_heures": 744,
           "noeud_en_retard": null, "statut_en_retard": null},
          {"tache": "backup", "noeud": "nœud-a", "noeuds": [], "noeud_enregistre": true, "portee": "applicative",
           "statut": "ok", "derniere": "2026-11-10T01:00:00", "retard_heures": 5.5, "periodicite_heures": 30,
           "noeud_en_retard": null, "statut_en_retard": null},
          {"tache": "telemetrie", "noeud": "nœud-a", "noeuds": [], "noeud_enregistre": true, "portee": "applicative",
           "statut": "erreur", "derniere": "2026-11-10T00:15:00", "retard_heures": 6.2, "periodicite_heures": 30,
           "noeud_en_retard": null, "statut_en_retard": null}
         ],
         "anomalies_recentes": [
          {"tache": "telemetrie", "noeud": "nœud-a", "cree_le": "2026-11-10T00:15:00",
           "erreur": "Agrégation interrompue : la table des évènements est verrouillée."}
         ],
         "anomalies_fenetre_jours": 7,
         "genere_le": "2026-11-10T06:30:00"
        }
        """#

    /// GET /admin/export-copropriete/dernier → `DernierExport`.
    static let dernier = #"""
        {"archive": "export-copropriete-2026-11-09.tar.gz", "cree_le": "2026-11-09T02:40:00",
         "octets": 48234496, "tables": 64, "lignes": 152340, "fichiers": 318}
        """#

    static let parSchema: [Reponse] = [
        Reponse(nom: "sante", schema: "SanteMaintenance", json: sante),
        Reponse(nom: "dernier", schema: "DernierExport", json: dernier),
    ]

    static func santeLue() throws -> SanteTaches {
        SanteTaches(try Relecture.generee(Components.Schemas.SanteMaintenance.self, json: sante))
    }

    static func dernierExportLu() throws -> DernierExport {
        DernierExport(try Relecture.generee(Components.Schemas.DernierExport.self, json: dernier))
    }
}
#endif
