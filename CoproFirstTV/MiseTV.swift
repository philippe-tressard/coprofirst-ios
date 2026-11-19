// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import CoreGraphics

/// Les mesures propres à l'écran de hall (#218) — celles de la charte se lisent dans `Mise`.
/// L'Apple TV pose ses vues sur 1920 × 1080 points, lues à trois mètres et plus.
enum MiseTV {
    /// La largeur d'une phrase : au-delà, l'œil perd la ligne d'un bord à l'autre de l'écran
    /// (relevé au simulateur le 15/11/2026, la phrase d'attente courait sur 1 800 points).
    static let mesure: CGFloat = 1_200
    /// La colonne des photos d'une affiche, à droite du texte (lot 3, 18/11/2026) : un peu
    /// plus d'un tiers de l'écran, le texte garde sa mesure.
    static let colonnePhotos: CGFloat = 640
    /// Le code d'appairage, lu de l'autre bout du hall : huit lettres, en chasse fixe.
    static let code: CGFloat = 140
    /// L'espace entre deux lettres du code : « B C D F », pas un mot.
    static let approcheCode: CGFloat = 16
    /// La place du code, réservée : l'en-tête ne saute pas quand le code arrive.
    static let placeCode: CGFloat = 260
    /// Entre deux blocs d'un même état (le code et son échéance, une photo et la suivante).
    static let ecart: CGFloat = 24
    /// Le repère d'une affiche, en bas de l'écran.
    static let repere: CGFloat = 14
}

/// Le rythme de l'écran de hall (#218, lot 3, 18/11/2026) : ce que le serveur n'impose pas.
enum RythmeTV {
    /// Le temps d'une affiche à l'écran : de quoi lire un titre et trois phrases de loin.
    static let parAffiche: Duration = .seconds(15)
    /// Entre deux lectures des affiches : une affiche créée paraît dans les deux minutes, et
    /// la lecture repousse l'échéance du jeton (glissante, trente jours).
    static let relecture: Duration = .seconds(120)
    /// Le fondu d'une affiche à la suivante — un changement ambiant, pas une réponse au geste.
    static let fondu: Double = 0.6
}
