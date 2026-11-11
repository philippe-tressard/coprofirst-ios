// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.76.0 (commit 92633e233a414f3d20d189055d71ea62a0b36b41), front/src/styles/socle.css.
// Jetons non portés (color-mix, valeur non littérale) :
//   --color-fond-logo: transparent
//   --color-success-plein-survol: color-mix(in srgb, var(--color-success-plein) 85%, black)

import SwiftUI

/// Les couleurs d'une palette de CoproFirst : un jeton `--color-*`, `--fil-*`, `--kanban-*`,
/// `--serie-*` ou `--palier-*` chacune, claire et sombre. La charte est `seine` ; une
/// résidence choisit la sienne (`site_palette`).
struct Palette: Sendable {
    let code: String
    /// `--color-accent`
    let accent: Color
    /// `--color-accent-plein`
    let accentPlein: Color
    /// `--color-bg`
    let bg: Color
    /// `--color-border`
    let border: Color
    /// `--color-border-champ`
    let borderChamp: Color
    /// `--color-danger`
    let danger: Color
    /// `--color-danger-bordure`
    let dangerBordure: Color
    /// `--color-danger-fond`
    let dangerFond: Color
    /// `--color-danger-plein`
    let dangerPlein: Color
    /// `--color-import-lie`
    let importLie: Color
    /// `--color-info`
    let info: Color
    /// `--color-info-bordure`
    let infoBordure: Color
    /// `--color-info-fond`
    let infoFond: Color
    /// `--color-info-plein`
    let infoPlein: Color
    /// `--color-jaune-fond`
    let jauneFond: Color
    /// `--color-jaune-texte`
    let jauneTexte: Color
    /// `--color-neutre-bordure`
    let neutreBordure: Color
    /// `--color-neutre-fond`
    let neutreFond: Color
    /// `--color-orange`
    let orange: Color
    /// `--color-orange-bordure`
    let orangeBordure: Color
    /// `--color-orange-fond`
    let orangeFond: Color
    /// `--color-orange-texte`
    let orangeTexte: Color
    /// `--color-primary`
    let primary: Color
    /// `--color-primary-dark`
    let primaryDark: Color
    /// `--color-primary-light`
    let primaryLight: Color
    /// `--color-primary-plein`
    let primaryPlein: Color
    /// `--color-primary-plein-survol`
    let primaryPleinSurvol: Color
    /// `--color-sarcelle`
    let sarcelle: Color
    /// `--color-sarcelle-bordure`
    let sarcelleBordure: Color
    /// `--color-sarcelle-fond`
    let sarcelleFond: Color
    /// `--color-sarcelle-plein`
    let sarcellePlein: Color
    /// `--color-secondary`
    let secondary: Color
    /// `--color-success`
    let success: Color
    /// `--color-success-bordure`
    let successBordure: Color
    /// `--color-success-fond`
    let successFond: Color
    /// `--color-success-plein`
    let successPlein: Color
    /// `--color-success-texte`
    let successTexte: Color
    /// `--color-sur-accent`
    let surAccent: Color
    /// `--color-sur-plein`
    let surPlein: Color
    /// `--color-sur-plein-discret`
    let surPleinDiscret: Color
    /// `--color-sur-voile`
    let surVoile: Color
    /// `--color-surface`
    let surface: Color
    /// `--color-text`
    let text: Color
    /// `--color-text-inverse`
    let textInverse: Color
    /// `--color-text-muted`
    let textMuted: Color
    /// `--color-violet`
    let violet: Color
    /// `--color-violet-fond`
    let violetFond: Color
    /// `--color-voile-modale`
    let voileModale: Color
    /// `--color-warning`
    let warning: Color
    /// `--color-warning-bordure`
    let warningBordure: Color
    /// `--color-warning-fond`
    let warningFond: Color
    /// `--color-warning-texte`
    let warningTexte: Color
    /// `--fil-ambre`
    let filAmbre: Color
    /// `--fil-ambre-fond`
    let filAmbreFond: Color
    /// `--fil-cyan`
    let filCyan: Color
    /// `--fil-cyan-fond`
    let filCyanFond: Color
    /// `--fil-fuchsia`
    let filFuchsia: Color
    /// `--fil-fuchsia-fond`
    let filFuchsiaFond: Color
    /// `--fil-inconnu`
    let filInconnu: Color
    /// `--fil-inconnu-fond`
    let filInconnuFond: Color
    /// `--fil-indigo`
    let filIndigo: Color
    /// `--fil-indigo-fond`
    let filIndigoFond: Color
    /// `--fil-olive`
    let filOlive: Color
    /// `--fil-olive-fond`
    let filOliveFond: Color
    /// `--fil-rose`
    let filRose: Color
    /// `--fil-rose-fond`
    let filRoseFond: Color
    /// `--fil-rouge`
    let filRouge: Color
    /// `--fil-rouge-fond`
    let filRougeFond: Color
    /// `--fil-sarcelle`
    let filSarcelle: Color
    /// `--fil-sarcelle-fond`
    let filSarcelleFond: Color
    /// `--fil-vert`
    let filVert: Color
    /// `--fil-vert-fond`
    let filVertFond: Color
    /// `--fil-violet`
    let filViolet: Color
    /// `--fil-violet-fond`
    let filVioletFond: Color
    /// `--kanban-ag`
    let kanbanAg: Color
    /// `--kanban-annule`
    let kanbanAnnule: Color
    /// `--kanban-cs`
    let kanbanCs: Color
    /// `--kanban-fournisseur`
    let kanbanFournisseur: Color
    /// `--kanban-syndic`
    let kanbanSyndic: Color
    /// `--kanban-termine`
    let kanbanTermine: Color
    /// `--palier-1`
    let palier1: Color
    /// `--palier-2`
    let palier2: Color
    /// `--palier-3`
    let palier3: Color
    /// `--palier-4`
    let palier4: Color
    /// `--serie-1`
    let serie1: Color
    /// `--serie-2`
    let serie2: Color
    /// `--serie-3`
    let serie3: Color
    /// `--serie-4`
    let serie4: Color
    /// `--serie-5`
    let serie5: Color
    /// `--serie-6`
    let serie6: Color
    /// `--serie-7`
    let serie7: Color
    /// `--serie-8`
    let serie8: Color
}

extension Palette {
    /// Toutes les palettes, par code (`site_palette` de GET /config).
    static let parCode: [String: Palette] = [
        "seine": .seine,
        "bordeaux": .bordeaux,
        "bouteille": .bouteille,
        "cuivre": .cuivre,
        "prune": .prune,
        "roi": .roi,
    ]
}
