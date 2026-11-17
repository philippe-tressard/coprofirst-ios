// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.103.0 (commit 1d1ed30cb3fa2128692ce2be0fe34ded87d72c69), front/src/lib/pages.ts#PAGES, front/src/lib/types-acces.ts#STATUTS_ACCES, front/src/lib/types-acces.ts#TYPES_ACCES, front/src/lib/bail.ts#ETATS_BAIL, front/src/lib/bail.ts#TYPES_OBJET_BAIL, front/src/lib/bail.ts#STATUTS_OBJET_BAIL, front/src/lib/constats.ts#GRAVITES_CONSTAT (tables-clients.json).
// swiftlint:disable line_length

/// Ce que le site écrit de « Mes lots & accès » et que le contrat ne sert pas.
enum TablesAcces {
    /// Le descriptif de chaque onglet de la page `mon-lot` (texte du site, parfois HTML).
    static let descriptifs: [String: String] = [
        "lots": "Situation de vos lots dans la résidence : appartements, caves et parkings.",
        "badges": "Vos badges Vigik : ceux que vous détenez (tableau ci-dessous), vos demandes (bouton « + Nouvel accès », en haut à droite, pour obtenir un badge supplémentaire) et vos déclarations (bouton « + Déclarer un accès », pour signaler un badge que vous détenez déjà). <a href=\"/faq#badge-prix\" style=\"font-size:.85rem\">Quel prix pour un badge ou une télécommande ?</a>",
        "telecommandes": "Vos télécommandes de parking : celles que vous détenez (tableau ci-dessous), vos demandes (bouton « + Nouvel accès », en haut à droite, pour obtenir une télécommande supplémentaire) et vos déclarations (bouton « + Déclarer un accès », pour signaler une télécommande que vous détenez déjà). <a href=\"/faq#badge-prix\" style=\"font-size:.85rem\">Quel prix pour un badge ou une télécommande ?</a>",
        "location": "Suivi de vos baux, locataires et documents de gestion locative.",
    ]
    /// L'état d'un badge ou d'une télécommande (`STATUTS_ACCES`).
    static let statutsAcces: [String: LibelleTeinte] = [
        "actif": LibelleTeinte("Actif", "badge-green"),
        "suspendu": LibelleTeinte("Suspendu", "badge-orange"),
        "perdu": LibelleTeinte("Perdu", "badge-red"),
    ]
    /// Les deux familles d'accès, dans l'ordre du site (`TYPES_ACCES`).
    static let typesAcces: [(code: String, libelle: String)] = [
        ("vigik", "🏷️ Badge Vigik"),
        ("telecommande", "📡 Télécommande parking"),
    ]
    /// L'état d'un bail (`ETATS_BAIL`).
    static let statutsBail: [String: LibelleTeinte] = [
        "actif": LibelleTeinte("Actif", "badge-green"),
        "en_cours_sortie": LibelleTeinte("En cours de sortie", "badge-yellow"),
        "termine": LibelleTeinte("Terminé", "badge-gray"),
    ]
    /// Le type d'un objet remis au locataire (`TYPES_OBJET_BAIL`).
    static let typesObjet: [String: String] = [
        "cle": "🔑 Clé",
        "telecommande": "📡 Télécommande",
        "vigik": "🏷️ Vigik",
        "autre": "📦 Autre",
    ]
    /// Le statut d'un objet remis (`STATUTS_OBJET_BAIL`).
    static let statutsObjet: [String: LibelleTeinte] = [
        "en_possession": LibelleTeinte("En possession", "badge-green"),
        "rendu": LibelleTeinte("Rendu", "badge-blue"),
        "perdu": LibelleTeinte("Perdu", "badge-red"),
        "non_remis": LibelleTeinte("Non remis", "badge-gray"),
    ]
    /// La gravité d'un constat sur un lot, du plus grave au moins grave (`GRAVITES_CONSTAT`).
    static let gravites: [(code: String, teinte: LibelleTeinte)] = [
        ("bloquant", LibelleTeinte("Bloquant", "badge-red")),
        ("inconnu", LibelleTeinte("Inconnu", "badge-gray")),
        ("avertissement", LibelleTeinte("À savoir", "badge-orange")),
        ("information", LibelleTeinte("Information", "badge-blue")),
    ]
}
// swiftlint:enable line_length
