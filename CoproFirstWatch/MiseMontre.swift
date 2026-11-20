// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import CoreGraphics

/// Les mesures propres à la montre (#226) — celles de la charte se lisent dans `Mise`, faite
/// pour un écran que l'on tient à la main. Au poignet, l'écran mesure 40 à 49 mm.
enum MiseMontre {
    /// Entre deux éléments d'une ligne ou d'un détail.
    static let espace: CGFloat = 6
    /// Entre le titre d'une alerte, sa marque et son âge.
    static let interligne: CGFloat = 2
    /// Le point des non lues — celui de l'iPhone (9 pt), réduit au poignet.
    static let point: CGFloat = 7
    /// Le point du widget sur le logo, en part de son côté — celui de la complication Wear OS
    /// (rayon 14 sur 96).
    static let pointDuWidget: CGFloat = 0.29
    /// Jusqu'où la phrase du widget rectangulaire se réduit avant de se couper (très grand texte).
    static let reductionDuWidget: CGFloat = 0.8
}
