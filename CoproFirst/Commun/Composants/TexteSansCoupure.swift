// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

/// Un libellé court, en `body` par défaut, qui ne coupe jamais un mot : il passe à la ligne
/// ENTRE deux mots, et quand son plus long mot ne tient pas sur la largeur offerte, il
/// descend d'une taille de texte, puis d'une autre, jusqu'à ce qu'il tienne — sans
/// passer sous son plancher (la taille par défaut, sauf mention). Le système, lui, coupe
/// le mot en syllabes (« An-nuaire », #33 ; « Communau-té » sur la tranche du carnet, #119).
///
/// `style`, `alignement` et `plancher` servent un libellé étroit : l'intercalaire du carnet
/// (`caption2`, centré), qui peut descendre sous la taille par défaut plutôt que couper.
///
/// La largeur est celle que l'écran donne vraiment (`onGeometryChange`) : `ViewThatFits`,
/// dans une cellule de liste, gardait la première taille et le mot débordait.
struct TexteSansCoupure: View {
    let texte: String
    var style = Font.TextStyle.body
    var alignement = TextAlignment.leading
    var plancher = DynamicTypeSize.large
    @Environment(\.dynamicTypeSize) private var taille
    @State private var largeur: CGFloat?

    var body: some View {
        let retenue = Self.taille(
            pour: Self.plusLongMot(texte), dans: largeur, depuis: taille, plancher: plancher, style: style)
        Text(texte)
            .font(.system(style))
            .multilineTextAlignment(alignement)
            .dynamicTypeSize(retenue)
            .frame(maxWidth: .infinity, alignment: alignement == .center ? .center : .leading)
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { largeur = $0 }
    }

    /// La plus grande taille, de la taille choisie à la taille par défaut, où `mot`
    /// tient sur `largeur` ; la plus petite essayée s'il ne tient nulle part. Sans
    /// largeur connue, la taille choisie.
    nonisolated static func taille(
        pour mot: String, dans largeur: CGFloat?, depuis taille: DynamicTypeSize,
        plancher: DynamicTypeSize = .large, style: Font.TextStyle = .body
    ) -> DynamicTypeSize {
        guard let largeur else { return taille }
        let essais = tailles(depuis: taille, plancher: plancher)
        return essais.first { largeurDe(mot, en: $0, style: style) <= largeur } ?? essais.last ?? taille
    }

    /// Les tailles à essayer, de la taille choisie jusqu'au plancher (la taille par défaut).
    nonisolated static func tailles(
        depuis taille: DynamicTypeSize, plancher: DynamicTypeSize = .large
    ) -> [DynamicTypeSize] {
        let plancher = min(taille, plancher)
        return DynamicTypeSize.allCases.filter { $0 >= plancher && $0 <= taille }.reversed()
    }

    /// Le mot le plus long : c'est lui qui doit tenir sur une ligne.
    nonisolated static func plusLongMot(_ texte: String) -> String {
        let mots: [Substring] = texte.split(whereSeparator: { (lettre: Character) in lettre.isWhitespace })
        return mots.max { $0.count < $1.count }.map(String.init) ?? texte
    }

    /// La largeur de `mot` dans ce style, à cette taille — la police que `Text` emploie.
    nonisolated static func largeurDe(
        _ mot: String, en taille: DynamicTypeSize, style: Font.TextStyle = .body
    ) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(taille))
        let police = UIFont.preferredFont(forTextStyle: uikit(style), compatibleWith: traits)
        return ceil((mot as NSString).size(withAttributes: [.font: police]).width)
    }

    /// Le même style, pour mesurer avec UIKit.
    nonisolated static func uikit(_ style: Font.TextStyle) -> UIFont.TextStyle {
        stylesUIKit[style] ?? .body
    }

    private nonisolated static let stylesUIKit: [Font.TextStyle: UIFont.TextStyle] = [
        .largeTitle: .largeTitle, .title: .title1, .title2: .title2, .title3: .title3,
        .headline: .headline, .subheadline: .subheadline, .body: .body, .callout: .callout,
        .footnote: .footnote, .caption: .caption1, .caption2: .caption2,
    ]
}
