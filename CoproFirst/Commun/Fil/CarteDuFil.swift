// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Un élément du fil : sa gouttière (`VignetteDeNature`), le titre, une ligne.
/// Une urgence porte le liseré rouge à gauche, comme une affaire urgente ; une affaire
/// datée, sa vignette d'échéance sous le classement (`VignetteEcheance`, #75) ; une
/// affaire, qui la lit et son lieu sous le texte (#129, #130). Ses pièces
/// jointes, une vignette à droite (`VignettePieces`, `FluxVignette` du site) : elle se lit
/// avec la session de la résidence, et ne paraît donc pas sans elle (la vitrine).
struct CarteDuFil: View {
    let element: ElementDuFil
    var installation: Installation?
    @Environment(\.palette) private var palette

    @Environment(\.dynamicTypeSize) private var tailleTexte

    /// Aux tailles d'accessibilité, la carte s'EMPILE (#266) : la gouttière, les pièces et le
    /// chevron sur une rangée, puis le texte sur toute la largeur. En ligne, la gouttière et
    /// la vignette des pièces lui laissaient une colonne où « Urgent » devenait « Urgen-t ».
    nonisolated static func empilee(_ taille: DynamicTypeSize) -> Bool { taille.isAccessibilitySize }

    /// Le retrait de la carte, et la largeur du liseré d'une urgence.
    static let marge: CGFloat = 14
    static let lisere: CGFloat = 4

    var body: some View {
        let nature = element.nature
        Group {
            if Self.empilee(tailleTexte) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 12) {
                        VignetteDeNature(element: element)
                        Spacer(minLength: 0)
                        pieces
                        chevron
                    }
                    texte(nature)
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    VignetteDeNature(element: element)
                    texte(nature)
                    Spacer(minLength: 0)
                    pieces
                    chevron.frame(maxHeight: .infinity)
                }
            }
        }
        .padding(Self.marge)
        .padding(.leading, element.urgent ? Self.lisere : 0)
        .background(palette.surface)
        .overlay(alignment: .leading) {
            if element.urgent { palette.danger.frame(width: Self.lisere) }
        }
        .clipShape(.rect(cornerRadius: Mise.rayon, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous).strokeBorder(palette.border, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(libelleVocal(nature))
    }

    /// Rubrique et heure, l'échéance, le titre, l'aperçu, qui la lit et où.
    private func texte(_ nature: NatureDuFil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Rubrique, heure, puis nature : sur une ligne tant qu'elle tient, sinon l'une sous
            // l'autre (très grand texte) — un libellé ne se coupe jamais (#57).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { enTete(nature) }.fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 2) { enTete(nature) }
            }
            // Une affaire datée dit quand elle a lieu, sous son classement (#75).
            if let echeance = element.echeance {
                VignetteEcheance(echeance: echeance, teinte: palette[keyPath: nature.couleur])
            }
            Text(element.titre)
                .font(.headline)
                .foregroundStyle(palette.text)
            if let detail = element.detail.map(TexteDuSite.apercu), !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(2)
            }
            // Qui la lit, puis où (#129, #130) — rien hors affaire ni pour le défaut.
            if Lecture.aMontrer(element.lecture) != nil || element.lieu != nil {
                FlowEtiquettes(espace: 6) {
                    PastilleLecture(lecture: element.lecture)
                    EtiquetteLieu(lieu: element.lieu)
                }
                .font(.caption)
                .foregroundStyle(palette.textMuted)
            }
        }
    }

    /// Les pièces jointes : une vignette, avec la session de la résidence seulement.
    @ViewBuilder private var pieces: some View {
        if let installation, !element.pieces.vide {
            VignettePieces(pieces: element.pieces, installation: installation)
        }
    }

    /// Une carte du fil s'ouvre TOUJOURS : le chevron le dit.
    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(palette.textMuted)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func enTete(_ nature: NatureDuFil) -> some View {
        Text(element.urgent ? "Urgent" : nature.libelle)
            .font(.caption.weight(.bold))
            .foregroundStyle(element.urgent ? palette.danger : palette[keyPath: nature.couleur])
        Text(FormatsDuSite.heure(element.date))
            .font(.caption.monospacedDigit())
            .foregroundStyle(palette.textMuted)
        if let classe = element.natureEnPastille { PastilleNature(nature: classe) }
    }

    private func libelleVocal(_ nature: NatureDuFil) -> Text {
        var morceaux = [element.urgent ? "Urgent" : nature.libelle, element.titre]
        if let classe = element.natureEnPastille { morceaux.append(classe.libelle) }
        morceaux.append(FormatsDuSite.heure(element.date))
        if let echeance = element.echeance { morceaux.append(echeance.enClair) }
        if let lecture = Lecture.aMontrer(element.lecture) { morceaux.append(lecture.enClair()) }
        if let lieu = element.lieu { morceaux.append(lieu) }
        if let detail = element.detail { morceaux.append(TexteDuSite.apercu(detail)) }
        if let pieces = element.pieces.enClair { morceaux.append(pieces) }
        return Text(morceaux.joined(separator: ", "))
    }
}
