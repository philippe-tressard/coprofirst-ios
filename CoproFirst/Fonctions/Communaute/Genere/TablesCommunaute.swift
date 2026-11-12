// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.89.0 (commit 10b85f3356d538254bfdca6f54270063c9008d4b), front/src/lib/idees.ts#STATUTS_IDEE, front/src/lib/annonces.ts#TYPES_ANNONCE, front/src/lib/annonces.ts#CATEGORIES_ANNONCE, front/src/lib/annonces.ts#TRIS_ANNONCE, front/src/lib/annonces.ts#STATUTS_ANNONCE, front/src/lib/annonces.ts#TEINTE_STATUT_ANNONCE (tables-clients.json) ; api/app/utils/avis.py.

/// Ce que le site écrit de la Communauté et que le contrat ne sert pas.
enum TablesCommunaute {
    /// Les états d'une idée, dans l'ordre du cycle de vie (`STATUTS_IDEE`).
    static let statutsIdee: [EntreeStatut] = [
        EntreeStatut(code: "ouverte", libelle: "💡 Ouverte", pastille: "badge-blue"),
        EntreeStatut(code: "retenue", libelle: "✅ Retenue", pastille: "badge-green"),
        EntreeStatut(code: "realisee", libelle: "🎉 Réalisée", pastille: "badge-purple"),
        EntreeStatut(code: "rejetee", libelle: "❌ Rejetée", pastille: "badge-gray"),
    ]
    /// Les types d'annonce (`TYPES_ANNONCE`).
    static let typesAnnonce: [(code: String, libelle: String)] = [
        ("vente", "🏷️ Vente"),
        ("don", "🎁 Don"),
        ("recherche", "🔍 Recherche"),
    ]
    /// Les catégories d'annonce (`CATEGORIES_ANNONCE`).
    static let categoriesAnnonce: [(code: String, libelle: String)] = [
        ("appartement", "🏠 Appartement"),
        ("parking_cave", "🅿️ Parking / Cave"),
        ("mobilier", "🛋️ Mobilier"),
        ("electromenager", "🫙 Électroménager"),
        ("high_tech", "💻 High-tech"),
        ("vehicule", "🚗 Véhicule"),
        ("vetements", "👗 Vêtements"),
        ("services", "🛠️ Services"),
        ("divers", "📦 Divers"),
    ]
    /// Les tris des annonces (`TRIS_ANNONCE`).
    static let trisAnnonce: [(code: String, libelle: String)] = [
        ("recent", "Plus récentes"),
        ("prix_asc", "Prix croissant"),
        ("prix_desc", "Prix décroissant"),
    ]
    /// Les états d'une annonce et leur teinte (`STATUTS_ANNONCE`, `TEINTE_STATUT_ANNONCE`).
    static let statutsAnnonce: [EntreeStatut] = [
        EntreeStatut(code: "en_cours", libelle: "En cours", pastille: "badge-green"),
        EntreeStatut(code: "reserve", libelle: "Réservé", pastille: "badge-orange"),
        EntreeStatut(code: "vendu", libelle: "Vendu", pastille: "badge-blue"),
        EntreeStatut(code: "donne", libelle: "Donné", pastille: "badge-blue"),
        EntreeStatut(code: "annule", libelle: "Annulé", pastille: "badge-gray"),
    ]
    /// La note d'un avis et ses seuils — la règle du SERVEUR (`utils/avis.py`) :
    /// sous `noteRemarque`, ce qui a manqué ; à partir de `notePubliable`, l'accord de diffusion.
    static let noteMin = 1
    static let noteMax = 5
    static let noteRemarque = 3
    static let notePubliable = 4
}
