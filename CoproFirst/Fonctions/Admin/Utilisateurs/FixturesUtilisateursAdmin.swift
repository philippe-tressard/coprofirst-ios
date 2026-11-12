// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Les comptes que l'API simulée sert à « Utilisateurs » — en JSON, à la forme de leur
/// route, lus par les types GÉNÉRÉS puis par le MÊME branchement que le service réel, et
/// jugés contre le contrat par `scripts/verifier-fixtures.py`.
///
/// Tout est inventé : aucun nom de personne réelle.
enum FixturesUtilisateursAdmin {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /admin/utilisateurs → `[UtilisateurAdminRead]`, avec ce que le serveur v3.88.1
    /// sert au-dessus du plancher (`auDessus`, `nomsServis`) : le nom affiché, « Prénom NOM »
    /// (#135), et les gestes de rôle d'un administrateur
    /// qui lit la liste — Camille est le seul administrateur, son rôle Admin ne se retire
    /// pas ; un compte inactif n'a aucun geste.
    static let utilisateurs = #"""
        [
          {"id": 11, "prenom": "Camille", "nom": "Exemple", "nom_affiche": "Camille EXEMPLE",
           "nom_aide_affiche": "", "est_moderateur": true, "email": "camille.exemple@exemple.fr",
           "statut": "copropriétaire_résident", "role": "propriétaire", "roles": ["propriétaire",
           "conseil_syndical", "admin"],
           "actif": true, "email_verifie": true, "batiment_nom": "Bâtiment A", "has_lots": true, "has_tc": true,
           "has_vigik": true, "has_bail": false, "etiquettes": {"loti": "ok", "tc": "ok", "vigik": "ok",
           "bail": "sans_objet"},
           "onboarding_complete": true, "onboarding_etape": 4, "preferences_notifications": "{}",
           "communaute_banni": false,
           "gestes_roles": {"conseil_syndical": "retirer", "admin": null, "operateur": "ajouter"},
           "derniere_connexion": "2026-11-09T18:20:00", "cree_le": "2025-03-02T10:00:00"},
          {"id": 12, "prenom": "Dominique", "nom": "Fictif", "nom_affiche": "Dominique FICTIF",
           "nom_aide_affiche": "", "est_moderateur": false, "email": "dominique@exemple.fr",
           "statut": "locataire", "role": "résident", "roles": ["résident"], "nom_proprietaire": "Sacha Exemple",
           "actif": true, "email_verifie": true, "batiment_nom": "Bâtiment B", "has_lots": true, "has_tc": false,
           "has_vigik": true, "has_bail": true, "etiquettes": {"loti": "ok", "tc": "manque", "vigik": "ok",
           "bail": "ok"},
           "onboarding_complete": true, "onboarding_etape": 4, "preferences_notifications": "{}",
           "communaute_ban_jusqu_au": "2026-12-05T10:00:00", "communaute_ban_count": 1, "communaute_banni": true,
           "gestes_roles": {"conseil_syndical": null, "admin": null, "operateur": null},
           "derniere_connexion": "2026-11-02T08:00:00", "cree_le": "2025-09-14T10:00:00"},
          {"id": 13, "prenom": "Alix", "nom": "Modèle", "nom_affiche": "Alix MODÈLE",
           "nom_aide_affiche": "", "est_moderateur": false, "email": "alix@exemple.fr",
           "statut": "copropriétaire_bailleur", "role": "propriétaire", "roles": ["propriétaire"],
           "actif": true, "email_verifie": true, "batiment_nom": null, "has_lots": false, "has_tc": false,
           "has_vigik": false, "has_bail": false, "etiquettes": {"loti": "manque", "tc": "sans_objet",
           "vigik": "sans_objet", "bail": "manque"},
           "onboarding_complete": false, "onboarding_etape": 2, "preferences_notifications": "{}",
           "communaute_banni": false,
           "gestes_roles": {"conseil_syndical": "ajouter", "admin": "ajouter", "operateur": null},
           "purge_avertie_le": "2026-10-28T06:00:00", "derniere_connexion": null, "cree_le": "2026-04-30T10:00:00"},
          {"id": 14, "prenom": "Morgan", "nom": "Fictif", "nom_affiche": "Morgan FICTIF",
           "nom_aide_affiche": "", "est_moderateur": false, "email": "morgan@exemple.fr",
           "statut": "copropriétaire_résident", "role": "propriétaire", "roles": ["propriétaire", "résident"],
           "actif": false, "email_verifie": false, "batiment_nom": "Bâtiment A", "has_lots": false, "has_tc": false,
           "has_vigik": false, "has_bail": false, "etiquettes": {"loti": "manque", "tc": "manque",
           "vigik": "manque", "bail": "sans_objet"},
           "onboarding_complete": false, "onboarding_etape": 0, "preferences_notifications": "{}",
           "communaute_banni": false,
           "gestes_roles": {"conseil_syndical": null, "admin": null, "operateur": null},
           "derniere_connexion": null, "cree_le": "2026-11-08T21:00:00"}
        ]
        """#

    /// POST /admin/utilisateurs/{id}/auto-match → `AutoMatchRelance` : l'annonce du serveur.
    static let rapprochement = #"""
        {"ok": true, "auto_match": {"lots": 0},
         "annonce": {"ton": "warning", "texte": "Aucun lot trouvé dans l'import pour ce compte."}}
        """#

    static let auDessus = AuDessusDuPlancher(
        schema: "UtilisateurAdminRead", champs: ["communaute_banni", "gestes_roles"], contrat: "1.18.0")

    static let nomsServis = AuDessusDuPlancher(
        schema: "UtilisateurAdminRead", champs: ["nom_affiche", "nom_aide_affiche", "est_moderateur"],
        contrat: "1.25.0")

    static let parSchema: [Reponse] = [
        Reponse(nom: "utilisateurs", schema: "UtilisateurAdminRead", json: utilisateurs),
        Reponse(nom: "rapprochement", schema: "AutoMatchRelance", json: rapprochement),
    ]

    static func lus() throws -> [UtilisateurAdmin] {
        UtilisateurAdmin.lus(
            try Relecture.generee([Components.Schemas.UtilisateurAdminRead].self, json: utilisateurs),
            corps: Data(utilisateurs.utf8))
    }

    static func annonceDuRapprochement() throws -> PhraseAvis {
        PhraseAvis(try Relecture.generee(Components.Schemas.AutoMatchRelance.self, json: rapprochement).annonce)
    }
}
#endif
