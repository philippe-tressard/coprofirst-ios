// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

/// La gouttière d'une carte du fil : le pictogramme qui la CLASSE (`classeDuFlux` du site)
/// dans la teinte de sa rubrique — la carte du fil et sa feuille de résumé la partagent.
struct VignetteDeNature: View {
    let element: ElementDuFil
    @Environment(\.palette) private var palette
    @ScaledMetric(relativeTo: .body) private var cote: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var trace: CGFloat = 21

    var body: some View {
        let nature = element.nature
        PictogrammeDuSite(nom: element.pictogramme, cote: trace)
            .foregroundStyle(palette[keyPath: nature.couleur])
            .frame(width: cote, height: cote)
            .background(palette[keyPath: nature.fond], in: .rect(cornerRadius: 10, style: .continuous))
            // Une vignette ne grandit pas sans fin : la nature se lit aussi dans le libellé.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityHidden(true)
    }
}

/// Un pictogramme du site, AU TRAIT, tel que `Icon.svelte` le dessine : le tracé Lucide
/// généré dans `Pictogrammes.xcassets` (`generateurs/pictogrammes.py`). Un nom qu'il ne
/// connaît pas retombe sur l'équivalent SF Symbols — jamais une image vide.
struct PictogrammeDuSite: View {
    let nom: String
    let cote: CGFloat

    /// Le nom de l'image dans le catalogue, si le tracé y est.
    static func image(_ nom: String) -> String? {
        let chemin = "Lucide/\(nom)"
        return UIImage(named: chemin) == nil ? nil : chemin
    }

    var body: some View {
        if let image = Self.image(nom) {
            Image(image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: cote, height: cote)
        } else {
            Image(systemName: Pictogrammes.symbole(nom))
                .font(.system(size: cote * 0.8, weight: .semibold))
                .frame(width: cote, height: cote)
        }
    }
}
