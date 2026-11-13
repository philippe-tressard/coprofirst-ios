// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.89.0 (commit 10b85f3356d538254bfdca6f54270063c9008d4b), front/src/lib/pages.ts#PAGES, front/src/lib/roles.ts#ROLES_DU_DROIT, front/src/lib/roles.ts#STATUTS_DU_PROFIL (tables-clients.json).

/// Les onglets de chaque page du site, dans leur ordre, avec leur réserve (#29).
/// La règle qui en décide l'ouverture : `OngletsDuSite.ouverts` (Navigation/OngletsOuverts.swift).
enum OngletsDuSite {
    static let parPage: [String: [OngletDuSite]] = [
        "residence": [
            OngletDuSite(id: "fiche", libelle: "Fiche", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "carnet", libelle: "Carnet d’entretien", reserve: .proprioOuCS, ouvertOperateur: false),
            OngletDuSite(id: "reglement", libelle: "Règlement", reserve: .proprioOuCS, ouvertOperateur: false),
        ],
        "mes-demandes": [
            OngletDuSite(id: "liste", libelle: "Liste", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "kanban", libelle: "Kanban", reserve: .nonLocataire, ouvertOperateur: false),
            OngletDuSite(id: "archives", libelle: "Archives", reserve: nil, ouvertOperateur: false),
        ],
        "mon-lot": [
            OngletDuSite(id: "lots", libelle: "Mes lots", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "badges", libelle: "Mes badges d’accès (Vigik)", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "telecommandes", libelle: "Télécommandes de parking", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "location", libelle: "Gestion locative", reserve: nil, ouvertOperateur: false),
        ],
        "prestataires": [
            OngletDuSite(id: "prestataires", libelle: "Prestataires", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "contrats", libelle: "Contrats", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "consommations", libelle: "Consommations", reserve: nil, ouvertOperateur: false),
        ],
        "communaute": [
            OngletDuSite(id: "sondages", libelle: "Sondages", reserve: .nonGestionnaire, ouvertOperateur: false),
            OngletDuSite(id: "idees", libelle: "Boîte à idées", reserve: .nonGestionnaire, ouvertOperateur: false),
            OngletDuSite(id: "annonces", libelle: "Petites annonces", reserve: .nonGestionnaire, ouvertOperateur: false),
            OngletDuSite(id: "avis", libelle: "Avis", reserve: nil, ouvertOperateur: false),
        ],
        "espace-cs": [
            OngletDuSite(id: "validations", libelle: "Comptes & accès", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "badges", libelle: "Badges & télécommandes", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "reporting", libelle: "Reporting", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "annonces-hall", libelle: "Annonces Hall", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "annuaire", libelle: "Annuaire CS & Syndic", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "courriels", libelle: "Courriels affaires", reserve: nil, ouvertOperateur: false),
        ],
        "admin": [
            OngletDuSite(id: "a_traiter", libelle: "À traiter", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "utilisateurs", libelle: "Utilisateurs", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "audit_lots", libelle: "Audit lots", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "telemetry", libelle: "Télémétrie", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "imports", libelle: "Imports", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "copropriete", libelle: "Identité", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "perimetres", libelle: "Périmètres", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "equipements", libelle: "Équipements", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "lots", libelle: "Lots", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "fonctionnement", libelle: "Fonctionnement", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "legal", libelle: "Pages légales", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "services", libelle: "Services", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "smtp", libelle: "Courriel", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "whatsapp", libelle: "WhatsApp", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "ia", libelle: "Assistant IA", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "pages", libelle: "Menu et pages", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "connexion", libelle: "Connexion et pied de page", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "emails", libelle: "Modèles e-mail", reserve: nil, ouvertOperateur: false),
            OngletDuSite(id: "installation", libelle: "Installation", reserve: .operateur, ouvertOperateur: true),
            OngletDuSite(id: "maintenance", libelle: "Maintenance", reserve: nil, ouvertOperateur: true),
            OngletDuSite(id: "installations", libelle: "Installations", reserve: .operateur, ouvertOperateur: true),
        ],
    ]

    /// Les pages de l'administration : un non-administrateur n'y ouvre que les onglets
    /// `ouvertOperateur`, s'il est opérateur.
    static let pagesReserveesAdmin: Set<String> = ["admin"]

    /// Qui porte chaque droit : rôles (`ROLES_DU_DROIT`, que lit `aRole` de `stores/auth.ts`),
    /// statuts (`STATUTS_DU_PROFIL` de `roles.ts`). Le modérateur n'y est pas : il est servi
    /// (`est_moderateur`) ; `isProprioOuCS` = un de `rolesProprietaire`, ou modérateur.
    static let rolesAdministrateur: Set<String> = ["admin"]
    static let rolesOperateur: Set<String> = ["operateur"]
    static let rolesProprietaire: Set<String> = ["propriétaire"]
    /// `isAdminOnly` : un de ces rôles, et aucun des suivants (le compte technique).
    static let rolesAdminSeul: Set<String> = ["admin"]
    static let rolesSansAdminSeul: Set<String> = ["propriétaire", "résident", "conseil_syndical"]
    static let statutsLocataire: Set<String> = ["locataire"]
    static let statutsGestionnaire: Set<String> = ["syndic", "mandataire"]
}
