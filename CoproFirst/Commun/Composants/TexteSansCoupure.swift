// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

/// Un libellé court, en `body`, qui ne coupe jamais un mot : il passe à la ligne ENTRE
/// deux mots, et quand son plus long mot ne tient pas sur la largeur offerte, il
/// descend d'une taille de texte, puis d'une autre, jusqu'à ce qu'il tienne — sans
/// passer sous la taille par défaut. Le système, lui, coupe le mot en syllabes
/// (« An-nuaire », #33).
///
/// La largeur est celle que l'écran donne vraiment (`onGeometryChange`) : `ViewThatFits`,
/// dans une cellule de liste, gardait la première taille et le mot débordait.
struct TexteSansCoupure: View {
    let texte: String
    @Environment(\.dynamicTypeSize) private var taille
    @State private var largeur: CGFloat?

    var body: some View {
        Text(texte)
            .font(.body)
            .dynamicTypeSize(Self.taille(pour: Self.plusLongMot(texte), dans: largeur, depuis: taille))
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { largeur = $0 }
    }

    /// La plus grande taille, de la taille choisie à la taille par défaut, où `mot`
    /// tient sur `largeur` ; la plus petite essayée s'il ne tient nulle part. Sans
    /// largeur connue, la taille choisie.
    nonisolated static func taille(
        pour mot: String, dans largeur: CGFloat?, depuis taille: DynamicTypeSize
    ) -> DynamicTypeSize {
        guard let largeur else { return taille }
        let essais = tailles(depuis: taille)
        return essais.first { largeurDe(mot, en: $0) <= largeur } ?? essais.last ?? taille
    }

    /// Les tailles à essayer, de la taille choisie jusqu'à la taille par défaut.
    nonisolated static func tailles(depuis taille: DynamicTypeSize) -> [DynamicTypeSize] {
        let plancher = min(taille, .large)
        return DynamicTypeSize.allCases.filter { $0 >= plancher && $0 <= taille }.reversed()
    }

    /// Le mot le plus long : c'est lui qui doit tenir sur une ligne.
    nonisolated static func plusLongMot(_ texte: String) -> String {
        let mots: [Substring] = texte.split(whereSeparator: { (lettre: Character) in lettre.isWhitespace })
        return mots.max { $0.count < $1.count }.map(String.init) ?? texte
    }

    /// La largeur de `mot` en `body`, à cette taille — la police que `Text` emploie.
    nonisolated static func largeurDe(_ mot: String, en taille: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(taille))
        let police = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traits)
        return ceil((mot as NSString).size(withAttributes: [.font: police]).width)
    }
}
