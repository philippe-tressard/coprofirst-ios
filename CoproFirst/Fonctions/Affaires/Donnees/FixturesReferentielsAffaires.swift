// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Les référentiels que l'API simulée sert (`GET /tickets/referentiels`) — en JSON, lu par
/// le type GÉNÉRÉ puis par `ReferentielsAffaires(lu:)`, comme le service réel. Les valeurs
/// sont celles du serveur à la version du plancher (`routers/tickets/referentiels.py`) ;
/// le serveur simulé y lit aussi la colonne et la clôture qu'il SERT sur chaque affaire.
enum FixturesReferentielsAffaires {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /tickets/referentiels → `ReferentielsAffaires`, pour le compte du conseil de la démo.
    static let referentiels = #"""
        {"categories": [
           {"code": "panne", "libelle": "Panne", "emoji": "🛠️",
            "description": "Ascenseur, chauffage, éclairage, fuite, porte — à réparer",
            "carnet": true, "reservee": false, "permise": true, "en_tete": false,
            "sections_essentielles": ["titre", "description"]},
           {"code": "nuisance", "libelle": "Nuisance & propreté", "emoji": "📢",
            "description": "Bruit, odeurs, stationnement…",
            "carnet": false, "reservee": false, "permise": true, "en_tete": false,
            "sections_essentielles": ["titre", "description"]},
           {"code": "acces_accueil", "libelle": "Accès & accueil", "emoji": "🔑",
            "description": "Interphone, boîte aux lettres, emménagement",
            "carnet": false, "reservee": false, "permise": true, "en_tete": false,
            "sections_essentielles": ["titre", "description"]},
           {"code": "espaces_verts", "libelle": "Espaces verts", "emoji": "🌳",
            "description": "Élagage, haies, arrosage, allées…",
            "carnet": true, "reservee": false, "permise": true, "en_tete": false,
            "sections_essentielles": ["titre", "description"]},
           {"code": "sinistre", "libelle": "Sinistre", "emoji": "💧",
            "description": "Dégât constaté : eau, incendie, vandalisme…",
            "carnet": true, "reservee": false, "permise": true, "en_tete": false,
            "sections_essentielles": ["titre", "description"]},
           {"code": "etude_travaux", "libelle": "Étude & travaux", "emoji": "🏗️",
            "description": "Diagnostic, sondage, devis, chantier suivi par le conseil",
            "carnet": true, "reservee": true, "permise": true, "en_tete": false,
            "sections_essentielles": ["titre", "description"]},
           {"code": "entretien", "libelle": "Entretien", "emoji": "🧰",
            "description": "Visite ou maintenance d’un prestataire, récurrente ou non",
            "carnet": true, "reservee": true, "permise": true, "en_tete": false,
            "sections_essentielles": ["titre", "description"]},
           {"code": "question", "libelle": "Question", "emoji": "❓",
            "description": "Information, procédure…",
            "carnet": false, "reservee": false, "permise": true, "en_tete": false,
            "sections_essentielles": ["titre", "description"]},
           {"code": "bug", "libelle": "Bug", "emoji": "🐛",
            "description": "Pb technique sur le site",
            "carnet": false, "reservee": false, "permise": true, "en_tete": false,
            "sections_essentielles": ["titre", "description"]},
           {"code": "actualite", "libelle": "Actualité", "emoji": "📰",
            "description": "Information — suivi optionnel",
            "carnet": false, "reservee": true, "permise": true, "en_tete": true,
            "sections_essentielles": ["titre", "description"]}],
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

    /// Lus comme le client généré les lit, branchés comme le service réel.
    static func lus() throws -> ReferentielsAffaires {
        let lu = try Relecture.generee(Components.Schemas.ReferentielsAffaires.self, json: referentiels)
        return ReferentielsAffaires(lu: lu)
    }
}
