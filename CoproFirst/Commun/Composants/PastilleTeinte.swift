// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Une pastille teintée : un libellé, et la classe `badge-*` que le site lui donne
/// (une couleur d'état de la charte). `PastilleStatut` en est le cas particulier du
/// statut d'une affaire (#37).
struct PastilleTeinte: View {
    let libelle: String
    /// La classe du site : `badge-green`, `badge-red`, `badge-blue`… (gris sinon).
    let badge: String
    /// Plus petite, pour une ligne dense (une capsule dans une carte).
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
    }

    /// Les couleurs d'état de la charte (texte, fond) pour chaque classe du site.
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

/// Un libellé et sa classe, tels qu'une table du site les écrit (`parAttribut`).
struct LibelleTeinte: Hashable, Sendable {
    let libelle: String
    let badge: String

    init(_ libelle: String, _ badge: String) {
        self.libelle = libelle
        self.badge = badge
    }

    /// Une valeur inconnue de la table s'affiche brute, en gris : un libellé
    /// manquant doit se voir.
    static func brut(_ valeur: String) -> LibelleTeinte { LibelleTeinte(valeur, "badge-gray") }
}
