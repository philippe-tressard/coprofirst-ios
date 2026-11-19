// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que la cloche montre d'un type d'alerte (table générée : `TypesNotification.swift`,
/// coprofirst#2802) : un pictogramme, et le mot qu'en dit un lecteur d'écran.
struct TypeNotification: Equatable, Sendable {
    /// Le nom Lucide du site ; `Pictogrammes.symbole` le traduit en SF Symbol.
    let pictogramme: String
    let libelle: String

    /// Le type d'une alerte servie ; un type inconnu de l'app prend celui par défaut,
    /// jamais une erreur.
    static func de(_ type: String) -> TypeNotification {
        TypesNotification.parType[type] ?? TypesNotification.parDefaut
    }
}
