// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Le tableau de bord que l'API simulée sert à « Télémétrie », une vue par réponse — en
/// JSON, à la forme de la route, que le contrat ne type pas (`ReponseNonTypee`).
///
/// Tout est inventé : aucun nom de personne réelle, aucune fréquentation réelle.
enum FixturesTelemetrie {
    /// GET /telemetry/dashboard?scope=jour.
    static let jour = #"""
        {
         "scope": "jour",
         "kpi": {"utilisateurs": 24, "vues": 146, "pages": 11, "heure_pointe": "18h", "moy_vues_utilisateur": 6.1},
         "chart": [
          {"label": "8h", "total": 6, "uniques": 3},
          {"label": "9h", "total": 14, "uniques": 5},
          {"label": "10h", "total": 9, "uniques": 4},
          {"label": "11h", "total": 12, "uniques": 6},
          {"label": "12h", "total": 7, "uniques": 4},
          {"label": "13h", "total": 5, "uniques": 3},
          {"label": "14h", "total": 11, "uniques": 5},
          {"label": "15h", "total": 8, "uniques": 4},
          {"label": "16h", "total": 10, "uniques": 5},
          {"label": "17h", "total": 16, "uniques": 7},
          {"label": "18h", "total": 22, "uniques": 9},
          {"label": "19h", "total": 17, "uniques": 8},
          {"label": "20h", "total": 9, "uniques": 4}
         ],
         "chart_label": "Vues par heure",
         "top_pages": [
          {"page": "/tableau-de-bord", "total": 58, "uniques": 21},
          {"page": "/mes-demandes", "total": 31, "uniques": 12},
          {"page": "/residence", "total": 18, "uniques": 9},
          {"page": "/communaute", "total": 12, "uniques": 7},
          {"page": "/annuaire", "total": 7, "uniques": 5}
         ],
         "top_users": [
          {"nom": "Camille Exemple", "derniere_connexion": "2026-11-10T18:42:00",
           "statut": "copropriétaire_résident", "batiment_id": 1, "total": 34, "pages": 9},
          {"nom": "Dominique Fictif", "derniere_connexion": "2026-11-10T17:05:00", "statut": "locataire",
           "batiment_id": 2, "total": 21, "pages": 6},
          {"nom": "Alix Modèle", "derniere_connexion": "2026-11-10T09:12:00",
           "statut": "copropriétaire_bailleur", "batiment_id": null, "total": 12, "pages": 4}
         ],
         "erreurs": [],
         "performance": {"indicateurs": [], "pages": []},
         "gestes": [],
         "arrivees": [],
         "adoption": null,
         "retour": null,
         "filtre_gestionnaire": {"propose": true, "gestionnaire_designe": true, "applique": "avec",
          "non_distingue_jusqu_au": null}
        }
        """#

    /// GET /telemetry/dashboard?scope=mois.
    static let mois = #"""
        {
         "scope": "mois",
         "kpi": {"vues": 1201, "utilisateurs": 16, "pages": 18, "heure_pointe": "18h", "moy_vues_jour": 40.0,
          "moy_utilisateurs_jour": 9.6, "jour_pointe": {"uniques": 16, "jour": "2026-11-04"},
           "vues_non_attribuees": 37},
         "chart": [
          {"label": "10-12", "total": 41, "uniques": 9},
          {"label": "10-13", "total": 38, "uniques": 8},
          {"label": "10-14", "total": 22, "uniques": 6},
          {"label": "10-15", "total": 19, "uniques": 5},
          {"label": "10-16", "total": 47, "uniques": 11},
          {"label": "10-17", "total": 52, "uniques": 12},
          {"label": "10-18", "total": 44, "uniques": 10},
          {"label": "10-19", "total": 39, "uniques": 9},
          {"label": "10-20", "total": 36, "uniques": 8},
          {"label": "10-21", "total": 18, "uniques": 5},
          {"label": "10-22", "total": 21, "uniques": 6},
          {"label": "10-23", "total": 49, "uniques": 12},
          {"label": "10-24", "total": 58, "uniques": 14},
          {"label": "10-25", "total": 51, "uniques": 12},
          {"label": "10-26", "total": 43, "uniques": 10},
          {"label": "10-27", "total": 40, "uniques": 9},
          {"label": "10-28", "total": 23, "uniques": 6},
          {"label": "10-29", "total": 20, "uniques": 5},
          {"label": "10-30", "total": 55, "uniques": 13},
          {"label": "10-31", "total": 61, "uniques": 15},
          {"label": "11-01", "total": 24, "uniques": 6},
          {"label": "11-02", "total": 22, "uniques": 6},
          {"label": "11-03", "total": 57, "uniques": 13},
          {"label": "11-04", "total": 66, "uniques": 16},
          {"label": "11-05", "total": 59, "uniques": 14},
          {"label": "11-06", "total": 48, "uniques": 11},
          {"label": "11-07", "total": 45, "uniques": 10},
          {"label": "11-08", "total": 26, "uniques": 7},
          {"label": "11-09", "total": 25, "uniques": 6},
          {"label": "11-10", "total": 52, "uniques": 12}
         ],
         "chart_label": "Vues par jour (30 j)",
         "top_pages": [
          {"page": "/tableau-de-bord", "total": 58, "uniques": 21},
          {"page": "/mes-demandes", "total": 31, "uniques": 12},
          {"page": "/residence", "total": 18, "uniques": 9},
          {"page": "/communaute", "total": 12, "uniques": 7},
          {"page": "/annuaire", "total": 7, "uniques": 5}
         ],
         "top_users": [
          {"nom": "Camille Exemple", "derniere_connexion": "2026-11-10T18:42:00",
           "statut": "copropriétaire_résident", "batiment_id": 1, "total": 34, "pages": 9},
          {"nom": "Dominique Fictif", "derniere_connexion": "2026-11-10T17:05:00", "statut": "locataire",
           "batiment_id": 2, "total": 21, "pages": 6},
          {"nom": "Alix Modèle", "derniere_connexion": "2026-11-10T09:12:00",
           "statut": "copropriétaire_bailleur", "batiment_id": null, "total": 12, "pages": 4}
         ],
         "erreurs": [],
         "performance": {"indicateurs": [], "pages": []},
         "gestes": [],
         "arrivees": [],
         "adoption": null,
         "retour": null,
         "filtre_gestionnaire": {"propose": true, "gestionnaire_designe": true, "applique": "avec",
          "non_distingue_jusqu_au": null}
        }
        """#

    /// GET /telemetry/dashboard?scope=annee.
    static let annee = #"""
        {
         "scope": "annee",
         "kpi": {"vues": 9155, "pages": 23, "record_jour": {"uniques": 19, "jour": "2026-10-14"},
          "record_mois": {"uniques": 51, "mois": "2026-10"}, "mois_actifs": 12, "moy_vues_mois": 762.9},
         "chart": [
          {"label": "2025-12", "total": 620, "uniques": 31},
          {"label": "2026-01", "total": 810, "uniques": 38},
          {"label": "2026-02", "total": 760, "uniques": 36},
          {"label": "2026-03", "total": 905, "uniques": 41},
          {"label": "2026-04", "total": 870, "uniques": 40},
          {"label": "2026-05", "total": 940, "uniques": 43},
          {"label": "2026-06", "total": 720, "uniques": 35},
          {"label": "2026-07", "total": 510, "uniques": 27},
          {"label": "2026-08", "total": 430, "uniques": 22},
          {"label": "2026-09", "total": 1020, "uniques": 46},
          {"label": "2026-10", "total": 1180, "uniques": 51},
          {"label": "2026-11", "total": 390, "uniques": 29}
         ],
         "chart_label": "Vues par mois (12 mois)",
         "top_pages": [
          {"page": "/tableau-de-bord", "total": 58, "uniques": 21},
          {"page": "/mes-demandes", "total": 31, "uniques": 12},
          {"page": "/residence", "total": 18, "uniques": 9},
          {"page": "/communaute", "total": 12, "uniques": 7},
          {"page": "/annuaire", "total": 7, "uniques": 5}
         ],
         "top_users": [],
         "erreurs": [],
         "performance": {"indicateurs": [], "pages": []},
         "gestes": [],
         "arrivees": [],
         "adoption": null,
         "retour": null,
         "filtre_gestionnaire": {"propose": false, "gestionnaire_designe": true, "applique": "avec",
          "non_distingue_jusqu_au": null}
        }
        """#

    /// GET /telemetry/dashboard?scope=total.
    static let total = #"""
        {
         "scope": "total",
         "kpi": {"vues": 18405, "pages": 26, "record_jour": {"uniques": 19, "jour": "2026-10-14"},
          "record_mois": {"uniques": 51, "mois": "2026-10"}, "annees_actives": 3, "moy_vues_an": 6135.0},
         "chart": [
          {"label": "2024", "total": 2140, "uniques": null},
          {"label": "2025", "total": 7310, "uniques": null},
          {"label": "2026", "total": 8955, "uniques": null}
         ],
         "chart_label": "Vues par année (10 ans)",
         "top_pages": [
          {"page": "/tableau-de-bord", "total": 58, "uniques": 21},
          {"page": "/mes-demandes", "total": 31, "uniques": 12},
          {"page": "/residence", "total": 18, "uniques": 9},
          {"page": "/communaute", "total": 12, "uniques": 7},
          {"page": "/annuaire", "total": 7, "uniques": 5}
         ],
         "top_users": [],
         "erreurs": [],
         "performance": {"indicateurs": [], "pages": []},
         "gestes": [],
         "arrivees": [],
         "adoption": null,
         "retour": null,
         "filtre_gestionnaire": {"propose": false, "gestionnaire_designe": true, "applique": "avec",
          "non_distingue_jusqu_au": null}
        }
        """#

    static let reponses: [PorteeTelemetrie: ReponseNonTypee] = [
        .jour: ReponseNonTypee(nom: "jour", route: "GET /telemetry/dashboard", json: jour),
        .mois: ReponseNonTypee(nom: "mois", route: "GET /telemetry/dashboard", json: mois),
        .annee: ReponseNonTypee(nom: "annee", route: "GET /telemetry/dashboard", json: annee),
        .total: ReponseNonTypee(nom: "total", route: "GET /telemetry/dashboard", json: total),
    ]

    static func tableau(_ portee: PorteeTelemetrie) throws -> TableauTelemetrie {
        guard let reponse = reponses[portee] else { throw ErreurService.inattendue(404) }
        return try reponse.lire(TableauTelemetrie.self)
    }
}
