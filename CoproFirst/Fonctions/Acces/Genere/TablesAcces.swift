// GÉNÉRÉ par scripts/generer-acces-prestataires.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// swiftlint:disable line_length
// Source : philippe-tressard/coprofirst v3.61.0 (commit 4239610fcf1658b53c84664087f7e5d0650fe834),
//   front/src/lib/pages.ts, types-acces.ts, bail.ts.

/// Ce que le site écrit de « Mes lots & accès » et que le contrat ne sert pas.
enum TablesAcces {
    /// Les onglets de la page `mon-lot`, leur libellé (sans pictogramme) et leur descriptif.
    static let onglets: [OngletDuSite] = [
        OngletDuSite(id: "lots", libelle: "Mes lots", descriptif: "Situation de vos lots dans la résidence : appartements, caves et parkings."),
        OngletDuSite(id: "badges", libelle: "Mes badges d’accès (Vigik)", descriptif: "Vos badges Vigik : ceux que vous détenez (tableau ci-dessous), vos demandes (bouton « + Nouvel accès », en haut à droite, pour obtenir un badge supplémentaire) et vos déclarations (bouton « + Déclarer un accès », pour signaler un badge que vous détenez déjà). <a href=\"/faq#badge-prix\" style=\"font-size:.85rem\">Quel prix pour un badge ou une télécommande ?</a>"),
        OngletDuSite(id: "telecommandes", libelle: "Télécommandes de parking", descriptif: "Vos télécommandes de parking : celles que vous détenez (tableau ci-dessous), vos demandes (bouton « + Nouvel accès », en haut à droite, pour obtenir une télécommande supplémentaire) et vos déclarations (bouton « + Déclarer un accès », pour signaler une télécommande que vous détenez déjà). <a href=\"/faq#badge-prix\" style=\"font-size:.85rem\">Quel prix pour un badge ou une télécommande ?</a>"),
        OngletDuSite(id: "location", libelle: "Gestion locative", descriptif: "Suivi de vos baux, locataires et documents de gestion locative."),
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
