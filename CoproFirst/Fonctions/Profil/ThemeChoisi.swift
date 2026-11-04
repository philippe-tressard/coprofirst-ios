// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le thème choisi au Profil : un réglage de L'APPAREIL, comme le cookie `theme` du
/// site (lib/theme.ts) — ni le compte ni la résidence ne le portent. Une valeur
/// inconnue retombe sur « Automatique ».
enum ThemeChoisi {
    /// La clé des réglages de l'app : le nom du cookie du site.
    static let cle = TablesProfil.cleTheme

    static func schema(_ code: String) -> ColorScheme? {
        switch code {
        case "clair": .light
        case "sombre": .dark
        default: nil
        }
    }
}

/// Pose le thème choisi sur toute la fenêtre — à appliquer UNE fois, à la racine.
private struct AppliquerTheme: ViewModifier {
    @AppStorage(ThemeChoisi.cle) private var theme = TablesProfil.themeParDefaut

    func body(content: Content) -> some View {
        content.preferredColorScheme(ThemeChoisi.schema(theme))
    }
}

extension View {
    /// Le thème « Automatique / Clair / Sombre » du Profil (#14).
    func themeChoisi() -> some View {
        modifier(AppliquerTheme())
    }
}

/// Un choix de thème : son code, son libellé, sa phrase.
struct OptionTheme {
    let code: String
    let libelle: String
    let detail: String
}

/// Un canal de notification et ses deux cases.
struct CanalNotifications {
    let titre: String
    let mon: String
    let autres: String
}
