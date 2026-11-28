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

    // Le Fil en tuiles (#429, maquette 5.2), sur 1920 × 1080 dans les marges sûres de tvOS :
    // 60 points en haut et en bas, 80 sur les côtés.
    static let largeurUtile: CGFloat = 1_920 - 2 * 80
    /// Entre deux tuiles, et entre deux rangées.
    static let joint: CGFloat = 24
    /// Le dedans d'une tuile, et son arrondi — celui des cartes de l'iPhone, à l'échelle du salon.
    static let dedans: CGFloat = 24
    static let rayon: CGFloat = 24
    /// Les cartes du carrousel visibles à la fois : quatre, lisibles à trois mètres.
    static let placesCarrousel = 4
    /// La hauteur d'une carte du carrousel : sa rubrique, deux lignes de titre, ses vignettes.
    static let carrousel: CGFloat = 230
    /// La vignette d'une photo sur une tuile, et le nombre qu'une tuile en montre avant « +N ».
    static let vignette: CGFloat = 64
    static let vignettesMax = 3
    /// Le QR code d'une tuile, puis celui de la mise en avant : plus gros, lu de plus loin.
    static let codeQR: CGFloat = 80
    /// Celui d'une ligne d'épinglé, et celui d'une carte du carrousel.
    static let codeQRPetit: CGFloat = 64
    static let codeQRAgrandi: CGFloat = 260
    /// La mise en avant : la part de l'écran qu'elle couvre, et la hauteur de sa mosaïque.
    static let miseEnAvantLargeur: CGFloat = 1_440
    static let miseEnAvantHauteur: CGFloat = 820
    static let mosaique: CGFloat = 420
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

    // Le Fil en tuiles (#429) : fixe dans l'app au départ ; un réglage par écran dans l'Espace
    // CS pourra venir (« à arbitrer » de #429).
    /// Le carrousel avance d'une carte, par cran (12 à 15 s), jamais en continu.
    static let cran: Duration = .seconds(13)
    /// Une mise en avant environ toutes les 30 s, ouverte 10 s.
    static let miseEnAvant: Duration = .seconds(30)
    static let ouverture: Duration = .seconds(10)
    /// Entre deux lectures du Fil : un vote compte à l'écran dans la minute.
    static let relectureDuFil: Duration = .seconds(60)
}
