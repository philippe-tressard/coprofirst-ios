// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

// ⚠️ PROVISOIRE (#14). Deux déclarations en attendant le commun : les onglets de la
// page `communaute` et leurs réserves seront GÉNÉRÉS dans `Charte/OngletsDuSite.swift`
// (session « Amorce »), la teinte d'une pastille viendra de `PastilleTeinte` (session
// #13). Le jour où ils sont dans main, ce fichier disparaît d'un bloc.

/// Les onglets de la page `communaute` (`pages.ts:347-376`).
enum OngletCommunaute: String, CaseIterable, Identifiable {
    case sondages, idees, annonces, avis

    var id: String { rawValue }

    var libelle: String {
        switch self {
        case .sondages: "📊 Sondages"
        case .idees: "💡 Boîte à idées"
        case .annonces: "🏷️ Petites annonces"
        case .avis: "⭐ Avis"
        }
    }

    /// Le libellé du segment : sans pictogramme, il tient dans la largeur d'un iPhone.
    var court: String {
        switch self {
        case .sondages: "Sondages"
        case .idees: "Idées"
        case .annonces: "Annonces"
        case .avis: "Avis"
        }
    }
}

/// La teinte d'une pastille `badge-*` de la charte.
/// ⚠️ PROVISOIRE : la même table vit, privée, dans `PastilleStatut` (Commun) ; une
/// entrée publique y est demandée à la coordination, et celle-ci disparaîtra.
enum TeintePastille {
    static func couleurs(_ pastille: String) -> (texte: KeyPath<Palette, Color>, fond: KeyPath<Palette, Color>) {
        switch pastille {
        case "badge-blue": (\.info, \.infoFond)
        case "badge-purple": (\.violet, \.violetFond)
        case "badge-orange": (\.orangeTexte, \.orangeFond)
        case "badge-yellow": (\.jauneTexte, \.jauneFond)
        case "badge-green": (\.successTexte, \.successFond)
        default: (\.textMuted, \.neutreFond)
        }
    }
}
