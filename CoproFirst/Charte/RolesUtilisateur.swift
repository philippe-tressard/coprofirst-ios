// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.66.0 (commit 14fec7b6ba683cd74161d874e48a47f2d007ff5f), front/src/lib/roles.ts et components/EnteteAccueil.svelte.

/// Les libellés des rôles et statuts d'un utilisateur, comme le site les écrit.
enum RolesUtilisateur {
    static let libellesRole: [String: String] = [
        "résident": "Résident",
        "propriétaire": "Propriétaire",
        "conseil_syndical": "Conseil syndical",
        "admin": "Admin",
        "externe": "Externe",
        "operateur": "Opérateur",
    ]
    static let libellesStatut: [String: String] = [
        "copropriétaire_résident": "Copropriétaire résident",
        "copropriétaire_bailleur": "Copropriétaire bailleur",
        "locataire": "Locataire",
        "syndic": "Syndic",
        "mandataire": "Mandataire",
        "aidant": "Aidant (proche)",
        "admin_technique": "Compte technique",
    ]
    static let libellesHerites: [String: String] = [
        "bailleur": "Copropriétaire bailleur",
    ]
    /// Les rôles que l'en-tête de l'accueil ajoute au statut, dans cet ordre.
    static let misEnAvant: [String] = ["conseil_syndical", "admin"]
}
