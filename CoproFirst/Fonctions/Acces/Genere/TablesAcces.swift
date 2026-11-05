// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.66.0 (commit 14fec7b6ba683cd74161d874e48a47f2d007ff5f), front/src/lib/pages.ts, types-acces.ts, bail.ts.
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
    /// L'état d'un bail (`ETAT` de `bail.ts`).
    static let statutsBail: [String: LibelleTeinte] = [
        "actif": LibelleTeinte("Actif", "badge-green"),
        "en_cours_sortie": LibelleTeinte("En cours de sortie", "badge-yellow"),
        "termine": LibelleTeinte("Terminé", "badge-gray"),
    ]
}
// swiftlint:enable line_length
