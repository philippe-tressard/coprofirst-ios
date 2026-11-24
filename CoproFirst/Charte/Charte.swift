// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

/// Une couleur en composantes 0–255, telle que la charte l'écrit.
struct RVBA: Sendable {
    let rouge: UInt8, vert: UInt8, bleu: UInt8
    let alpha: Double

    init(_ rouge: UInt8, _ vert: UInt8, _ bleu: UInt8, _ alpha: Double) {
        self.rouge = rouge
        self.vert = vert
        self.bleu = bleu
        self.alpha = alpha
    }

    var uiColor: UIColor {
        UIColor(
            red: CGFloat(rouge) / 255, green: CGFloat(vert) / 255, blue: CGFloat(bleu) / 255,
            alpha: CGFloat(alpha)
        )
    }
}

/// Typographie et mesures de l'app — écrites une fois.
///
/// Chacune est PROPRE À iOS, déclarée avec sa raison et sa date dans
/// `CoproFirstTests/MesuresTests.swift` ; une mesure dont le site a le jeton se lit dans
/// `MesuresDuSite` (généré). Une mesure ajoutée ici sans déclaration fait échouer le test (#85).
enum Mise {
    /// Rayon des cartes, des champs et des boutons (coins continus).
    static let rayon: CGFloat = 14
    /// Rayon d'une tuile posée DANS une carte : vignette de nature, choix d'un état, encadré (#347).
    static let rayonTuile: CGFloat = 10
    /// Marge latérale des écrans.
    static let marge: CGFloat = 20
    /// Hauteur minimale d'une cible tactile (Human Interface Guidelines).
    static let cible: CGFloat = 44
    /// Le côté d'un médaillon d'en-tête : le logo d'une résidence, le symbole d'un personnage (#347).
    static let medaillon: CGFloat = 44
    /// L'approche des libellés en capitales (`styleLibelle`).
    static let approcheLibelle: CGFloat = 0.6
    /// La hauteur de la mosaïque des photos d'un élément ouvert (`MosaiquePhotos`).
    static let mosaique: CGFloat = 220
    /// La même, sous une suite de l'Historique ou dans un message.
    static let mosaiqueCompacte: CGFloat = 140
    /// Le côté de la vignette d'une carte du fil (`VignettePieces`).
    static let vignette: CGFloat = 56
    /// La pastille d'une section du fil d'une affaire (`RailDuFil`, #178).
    static let jalon: CGFloat = 16
    /// Celle d'un élément sous une section.
    static let jalonSecondaire: CGFloat = 10
    /// Le trait du rail qui relie les pastilles.
    static let filetRail: CGFloat = 2
    /// La colonne de liste à côté d'une fiche, en classe régulière (`ListeEtFiche`, #222) :
    /// sa largeur idéale, puis ses bornes.
    static let listeIdeale: CGFloat = 360
    static let listeMin: CGFloat = 300
    static let listeMax: CGFloat = 440
    /// Le trait qui souligne la rangée dont la fiche est ouverte à côté (`rangeeChoisie`).
    static let filetChoisi: CGFloat = 2
    /// La largeur de la tranche du carnet, où se rangent les intercalaires (#119), au
    /// texte par défaut : elle suit Dynamic Type.
    static let tranche: CGFloat = 84
    /// L'écart de ce trait autour d'un lien dans le texte (le syndic, une annexe).
    static let debordChoisi: CGFloat = 6
    /// La colonne de lecture d'un écran (`largeurDeLecture`, #223), au texte par défaut :
    /// elle suit Dynamic Type.
    static let lecture: CGFloat = 720
}

extension Font {
    /// Un titre : le serif de la charte (New York), à la taille du style dynamique.
    static func titre(_ style: Font.TextStyle) -> Font {
        .system(style, design: .serif).weight(.semibold)
    }
}

extension View {
    /// Le libellé d'un champ ou d'une section : en capitales, comme le site.
    func styleLibelle() -> some View {
        modifier(StyleLibelle())
    }
}

private struct StyleLibelle: ViewModifier {
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.semibold))
            .tracking(Mise.approcheLibelle)
            .textCase(.uppercase)
            .foregroundStyle(palette.textMuted)
    }
}
