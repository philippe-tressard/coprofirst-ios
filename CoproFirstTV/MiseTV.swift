// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import CoreGraphics

/// Les mesures propres à l'écran de hall (#218) — celles de la charte se lisent dans `Mise`.
/// L'Apple TV pose ses vues sur 1920 × 1080 points, lues à trois mètres et plus.
enum MiseTV {
    /// La largeur d'une phrase : au-delà, l'œil perd la ligne d'un bord à l'autre de l'écran
    /// (relevé au simulateur le 15/11/2026, la phrase d'attente courait sur 1 800 points).
    static let mesure: CGFloat = 1_200
}
