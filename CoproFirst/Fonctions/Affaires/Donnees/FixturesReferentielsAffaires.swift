// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Les référentiels que l'API simulée sert (`GET /tickets/referentiels`) — en JSON, lu par
/// le type GÉNÉRÉ puis par `ReferentielsAffaires(lu:)`, comme le service réel. Les valeurs
/// sont celles du serveur à la version du plancher (`routers/tickets/referentiels.py`) ;
/// le serveur simulé y lit aussi la colonne et la clôture qu'il SERT sur chaque affaire.
/// Les catégories n'y sont pas écrites : elles viennent de `FixturesCategoriesServies`,
/// GÉNÉRÉE avec les sections essentielles que le serveur calcule (#69) — une seule liste.
enum FixturesReferentielsAffaires {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /tickets/referentiels → `ReferentielsAffaires`, pour le compte du conseil de la démo,
    /// hors des catégories (`lus()` les y pose).
    static let referentiels = #"""
        {"categories": [],
         "statuts": [
           {"code": "ouvert", "libelle": "Ouvert", "clos": false, "colonne_kanban": "cs",
            "proposable": true},
           {"code": "en_ag", "libelle": "À l’AG", "clos": false, "colonne_kanban": "ag",
            "proposable": true},
           {"code": "en_cours", "libelle": "Chez le syndic", "clos": false, "colonne_kanban": "syndic",
            "proposable": true},
           {"code": "chez_prestataire", "libelle": "Chez le prestataire", "clos": false,
            "colonne_kanban": "fournisseur",
            "proposable": true},
           {"code": "résolu", "libelle": "Résolu", "clos": true, "colonne_kanban": "termine",
            "proposable": true},
           {"code": "annulé", "libelle": "Annulé", "clos": true, "colonne_kanban": "annule",
            "proposable": true},
           {"code": "fermé", "libelle": "Fermé", "clos": false, "colonne_kanban": null,
            "proposable": false},
           {"code": "publie", "libelle": "Publiée", "clos": false, "colonne_kanban": null,
            "proposable": false}],
         "colonnes_kanban": [
           {"code": "ag", "libelle": "AG", "libelle_court": "AG"},
           {"code": "cs", "libelle": "CS (en cours)", "libelle_court": "CS"},
           {"code": "syndic", "libelle": "Syndic (en cours)", "libelle_court": "Syndic"},
           {"code": "fournisseur", "libelle": "Prestataire (en cours)", "libelle_court": "Prestataire"},
           {"code": "termine", "libelle": "Terminé", "libelle_court": "Terminé"},
           {"code": "annule", "libelle": "Annulé", "libelle_court": "Annulé"}],
         "natures": [{"code": "actualite", "libelle": "Actualité"}, {"code": "calendrier", "libelle": "Calendrier"},
                     {"code": "activite", "libelle": "Affaire"}]}
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "referentiels", schema: "ReferentielsAffaires", json: referentiels)
    ]

    /// Lus comme le client généré les lit, branchés comme le service réel. Le serveur sert
    /// à CE compte les catégories qu'il peut poser (`permise`) : la simulation fait comme lui
    /// — une catégorie réservée n'est permise qu'à qui modère (`categorie_permise`, #105).
    static func lus(moderateur: Bool = true) throws -> ReferentielsAffaires {
        var lu = try Relecture.generee(Components.Schemas.ReferentielsAffaires.self, json: referentiels)
        lu.categories = try Relecture.generee(
            [Components.Schemas.CategorieServie].self, json: FixturesCategoriesServies.categories
        ).map { categorie in
            var servie = categorie
            servie.permise = moderateur || !categorie.reservee
            return servie
        }
        return ReferentielsAffaires(lu: lu)
    }
}
#endif
