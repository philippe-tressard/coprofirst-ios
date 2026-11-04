// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// ⚠️ PROVISOIRE (#13) : une pastille teintée par la classe `badge-*` du site.
///
/// `PastilleStatut` (Commun) fait la même chose pour les affaires seules, et sa table
/// des teintes est privée. Ce composant servant à deux menus (Accès, Prestataires),
/// il ira dans `Commun/Composants/` — demande faite à la coordination le 04/11/2026.
/// D'ici là, il vit ici, et nulle part ailleurs.
struct PastilleTeinte: View {
    let libelle: String
    /// La classe du site : `badge-green`, `badge-red`, `badge-blue`…
    let badge: String
    var compacte = false
    @Environment(\.palette) private var palette

    var body: some View {
        let (texte, fond) = Self.teintes(badge)
        Text(libelle)
            .font(compacte ? .caption2.weight(.semibold) : .caption.weight(.semibold))
            .foregroundStyle(palette[keyPath: texte])
            .padding(.horizontal, compacte ? 8 : 10)
            .padding(.vertical, compacte ? 3 : 4)
            .background(palette[keyPath: fond], in: .capsule)
            .fixedSize()
    }

    /// Les couleurs d'état de la charte, comme `PastilleStatut` les associe aux classes.
    static func teintes(_ badge: String) -> (KeyPath<Palette, Color>, KeyPath<Palette, Color>) {
        switch badge {
        case "badge-blue": (\.info, \.infoFond)
        case "badge-purple": (\.violet, \.violetFond)
        case "badge-orange": (\.orangeTexte, \.orangeFond)
        case "badge-yellow": (\.jauneTexte, \.jauneFond)
        case "badge-green": (\.successTexte, \.successFond)
        case "badge-red": (\.danger, \.dangerFond)
        default: (\.textMuted, \.neutreFond)
        }
    }
}

/// Un libellé et sa teinte, tels qu'une table du site les écrit (`parAttribut`).
struct LibelleTeinte: Hashable, Sendable {
    let libelle: String
    let badge: String

    init(_ libelle: String, _ badge: String) {
        self.libelle = libelle
        self.badge = badge
    }

    /// Une valeur inconnue s'affiche brute, en gris — un libellé manquant doit se voir.
    static func brut(_ valeur: String) -> LibelleTeinte { LibelleTeinte(valeur, "badge-gray") }
}
