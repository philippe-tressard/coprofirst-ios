// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// GÉNÉRÉ par scripts/generer-charte.py — NE PAS MODIFIER À LA MAIN.
// Source : coprofirst@203f626a1, front/src/styles/socle.css et palette-sombre.css.
// Non portés (color-mix ou valeur non littérale) :
//   --color-fond-logo: transparent
//   --color-success-plein-survol: color-mix(in srgb, var(--color-success-plein) 85%, black)

import SwiftUI

/// Les couleurs de la charte de CoproFirst : une par jeton `--color-*`, claire et sombre.
enum Charte {
    /// `--color-accent`
    static let accent = Color(clair: RVBA(0xBD, 0x8C, 0x2C, 1), sombre: RVBA(0xC9, 0x98, 0x3A, 1))

    /// `--color-accent-plein`
    static let accentPlein = Color(clair: RVBA(0xBD, 0x8C, 0x2C, 1), sombre: RVBA(0xC9, 0x98, 0x3A, 1))

    /// `--color-bg`
    static let bg = Color(clair: RVBA(0xF2, 0xEF, 0xE9, 1), sombre: RVBA(0x0D, 0x1B, 0x2A, 1))

    /// `--color-border`
    static let border = Color(clair: RVBA(0xD0, 0xD8, 0xE4, 1), sombre: RVBA(0x2A, 0x3F, 0x5A, 1))

    /// `--color-border-champ`
    static let borderChamp = Color(clair: RVBA(0x7A, 0x88, 0x9C, 1), sombre: RVBA(0x65, 0x80, 0xA3, 1))

    /// `--color-danger`
    static let danger = Color(clair: RVBA(0xC0, 0x39, 0x2B, 1), sombre: RVBA(0xF2, 0x8B, 0x82, 1))

    /// `--color-danger-bordure`
    static let dangerBordure = Color(clair: RVBA(0xE6, 0xB0, 0xAA, 1), sombre: RVBA(0x6E, 0x4C, 0x54, 1))

    /// `--color-danger-fond`
    static let dangerFond = Color(clair: RVBA(0xFD, 0xED, 0xEC, 1), sombre: RVBA(0x3B, 0x34, 0x43, 1))

    /// `--color-danger-plein`
    static let dangerPlein = Color(clair: RVBA(0xC0, 0x39, 0x2B, 1), sombre: RVBA(0xC0, 0x39, 0x2B, 1))

    /// `--color-import-lie`
    static let importLie = Color(clair: RVBA(0x25, 0x63, 0xEB, 1), sombre: RVBA(0x65, 0x91, 0xF1, 1))

    /// `--color-info`
    static let info = Color(clair: RVBA(0x25, 0x63, 0xA6, 1), sombre: RVBA(0x6F, 0xAE, 0xEE, 1))

    /// `--color-info-bordure`
    static let infoBordure = Color(clair: RVBA(0xA8, 0xC1, 0xDB, 1), sombre: RVBA(0x3A, 0x5A, 0x80, 1))

    /// `--color-info-fond`
    static let infoFond = Color(clair: RVBA(0xE6, 0xF1, 0xFB, 1), sombre: RVBA(0x25, 0x3A, 0x55, 1))

    /// `--color-info-plein`
    static let infoPlein = Color(clair: RVBA(0x25, 0x63, 0xA6, 1), sombre: RVBA(0x25, 0x63, 0xA6, 1))

    /// `--color-jaune-fond`
    static let jauneFond = Color(clair: RVBA(0xFE, 0xF9, 0xE7, 1), sombre: RVBA(0x39, 0x3E, 0x3A, 1))

    /// `--color-jaune-texte`
    static let jauneTexte = Color(clair: RVBA(0xA1, 0x62, 0x07, 1), sombre: RVBA(0xE5, 0xC5, 0x4F, 1))

    /// `--color-neutre-bordure`
    static let neutreBordure = Color(clair: RVBA(0xE3, 0xE8, 0xEF, 1), sombre: RVBA(0x26, 0x3A, 0x57, 1))

    /// `--color-neutre-fond`
    static let neutreFond = Color(clair: RVBA(0xF7, 0xF8, 0xFA, 1), sombre: RVBA(0x1B, 0x2A, 0x41, 1))

    /// `--color-orange`
    static let orange = Color(clair: RVBA(0xC2, 0x41, 0x0C, 1), sombre: RVBA(0xF2, 0x89, 0x5B, 1))

    /// `--color-orange-bordure`
    static let orangeBordure = Color(clair: RVBA(0xFE, 0xD7, 0xAA, 1), sombre: RVBA(0x6E, 0x4B, 0x45, 1))

    /// `--color-orange-fond`
    static let orangeFond = Color(clair: RVBA(0xFF, 0xF7, 0xED, 1), sombre: RVBA(0x3B, 0x34, 0x3C, 1))

    /// `--color-orange-texte`
    static let orangeTexte = Color(clair: RVBA(0x9A, 0x34, 0x12, 1), sombre: RVBA(0xF6, 0xA7, 0x7C, 1))

    /// `--color-primary`
    static let primary = Color(clair: RVBA(0x1E, 0x3A, 0x5F, 1), sombre: RVBA(0x8D, 0xB4, 0xE8, 1))

    /// `--color-primary-dark`
    static let primaryDark = Color(clair: RVBA(0x16, 0x30, 0x4F, 1), sombre: RVBA(0xB9, 0xD1, 0xF2, 1))

    /// `--color-primary-light`
    static let primaryLight = Color(clair: RVBA(0xEE, 0xF2, 0xF7, 1), sombre: RVBA(0x1D, 0x31, 0x50, 1))

    /// `--color-primary-plein`
    static let primaryPlein = Color(clair: RVBA(0x1E, 0x3A, 0x5F, 1), sombre: RVBA(0x1F, 0x44, 0x74, 1))

    /// `--color-primary-plein-survol`
    static let primaryPleinSurvol = Color(clair: RVBA(0x16, 0x30, 0x4F, 1), sombre: RVBA(0x2A, 0x54, 0x89, 1))

    /// `--color-sarcelle`
    static let sarcelle = Color(clair: RVBA(0x0B, 0x64, 0x70, 1), sombre: RVBA(0x5C, 0xC5, 0xD1, 1))

    /// `--color-sarcelle-bordure`
    static let sarcelleBordure = Color(clair: RVBA(0x9D, 0xC1, 0xC6, 1), sombre: RVBA(0x32, 0x63, 0x74, 1))

    /// `--color-sarcelle-fond`
    static let sarcelleFond = Color(clair: RVBA(0xDD, 0xF1, 0xF4, 1), sombre: RVBA(0x22, 0x3E, 0x50, 1))

    /// `--color-sarcelle-plein`
    static let sarcellePlein = Color(clair: RVBA(0x0B, 0x64, 0x70, 1), sombre: RVBA(0x0B, 0x64, 0x70, 1))

    /// `--color-secondary`
    static let secondary = Color(clair: RVBA(0x3D, 0x6B, 0x4F, 1), sombre: RVBA(0x6F, 0xB4, 0x8C, 1))

    /// `--color-success`
    static let success = Color(clair: RVBA(0x2E, 0x7D, 0x52, 1), sombre: RVBA(0x5C, 0xC0, 0x8F, 1))

    /// `--color-success-bordure`
    static let successBordure = Color(clair: RVBA(0xAB, 0xCB, 0xBA, 1), sombre: RVBA(0x32, 0x61, 0x5A, 1))

    /// `--color-success-fond`
    static let successFond = Color(clair: RVBA(0xE6, 0xF4, 0xEE, 1), sombre: RVBA(0x22, 0x3D, 0x45, 1))

    /// `--color-success-plein`
    static let successPlein = Color(clair: RVBA(0x2E, 0x7D, 0x52, 1), sombre: RVBA(0x2E, 0x7D, 0x52, 1))

    /// `--color-success-texte`
    static let successTexte = Color(clair: RVBA(0x27, 0x6A, 0x46, 1), sombre: RVBA(0x7F, 0xD6, 0xA6, 1))

    /// `--color-sur-accent`
    static let surAccent = Color(clair: RVBA(0x1A, 0x1A, 0x2E, 1), sombre: RVBA(0x1A, 0x1A, 0x2E, 1))

    /// `--color-sur-plein`
    static let surPlein = Color(clair: RVBA(0xFF, 0xFF, 0xFF, 1), sombre: RVBA(0xFF, 0xFF, 0xFF, 1))

    /// `--color-sur-plein-discret`
    static let surPleinDiscret = Color(clair: RVBA(0xFF, 0xFF, 0xFF, 0.55), sombre: RVBA(0xFF, 0xFF, 0xFF, 0.62))

    /// `--color-sur-voile`
    static let surVoile = Color(clair: RVBA(0xFF, 0xFF, 0xFF, 1), sombre: RVBA(0xFF, 0xFF, 0xFF, 1))

    /// `--color-surface`
    static let surface = Color(clair: RVBA(0xFF, 0xFF, 0xFF, 1), sombre: RVBA(0x16, 0x22, 0x36, 1))

    /// `--color-text`
    static let text = Color(clair: RVBA(0x1A, 0x1A, 0x2E, 1), sombre: RVBA(0xE8, 0xE6, 0xE1, 1))

    /// `--color-text-inverse`
    static let textInverse = Color(clair: RVBA(0xF2, 0xEF, 0xE9, 1), sombre: RVBA(0xF2, 0xEF, 0xE9, 1))

    /// `--color-text-muted`
    static let textMuted = Color(clair: RVBA(0x5A, 0x60, 0x70, 1), sombre: RVBA(0x9F, 0xB0, 0xC6, 1))

    /// `--color-violet`
    static let violet = Color(clair: RVBA(0x6B, 0x21, 0xA8, 1), sombre: RVBA(0xC6, 0xA0, 0xF0, 1))

    /// `--color-violet-fond`
    static let violetFond = Color(clair: RVBA(0xF3, 0xE8, 0xFF, 1), sombre: RVBA(0x34, 0x37, 0x56, 1))

    /// `--color-voile-modale`
    static let voileModale = Color(clair: RVBA(0x00, 0x00, 0x00, 0.45), sombre: RVBA(0x00, 0x00, 0x00, 0.6))

    /// `--color-warning`
    static let warning = Color(clair: RVBA(0xB0, 0x7D, 0x1E, 1), sombre: RVBA(0xD9, 0xA4, 0x41, 1))

    /// `--color-warning-bordure`
    static let warningBordure = Color(clair: RVBA(0xDF, 0xCB, 0xA5, 1), sombre: RVBA(0x64, 0x56, 0x3A, 1))

    /// `--color-warning-fond`
    static let warningFond = Color(clair: RVBA(0xFD, 0xF3, 0xE0, 1), sombre: RVBA(0x37, 0x38, 0x38, 1))

    /// `--color-warning-texte`
    static let warningTexte = Color(clair: RVBA(0x7B, 0x58, 0x15, 1), sombre: RVBA(0xEB, 0xC3, 0x73, 1))
}
