// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La navigation de l'iPhone pliable ouvert (#119) : le carnet de la résidence. La page
/// retenue occupe la double page ; les intercalaires, sur la tranche droite, remplacent la
/// barre du bas — toutes les pages dans l'ordre réglé par l'administration (`pages_order`),
/// puis Profil et À propos. Une page que l'app ne porte pas encore s'ouvre sur « Bientôt »,
/// comme dans les autres présentations. Plié, l'app garde la barre du bas.
struct Carnet: View {
    let pages: [PageDeNavigation]
    let installation: Installation

    var body: some View {
        HStack(spacing: 0) {
            PageRetenue(pages: pages, installation: installation)
                .frame(maxWidth: .infinity)
            // Plafonnée AU-DESSUS des intercalaires : leur largeur (`@ScaledMetric`) lit la
            // taille de leur environnement, et s'étirait au tiers de l'écran au plus grand texte.
            Intercalaires(pages: pages)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }
}

/// Les intercalaires sur la tranche : celui de la page ouverte prend le fond de la page,
/// comme l'onglet d'un classeur qui dépasse de sa feuille ; les autres restent sur la
/// tranche. La colonne défile quand les pages dépassent sa hauteur (grand texte). Un libellé
/// ne se coupe jamais au milieu d'un mot (#33) : il descend d'une taille, au besoin sous la
/// taille par défaut, plutôt que d'écrire « Communau-té ». Ouvrir un intercalaire ne change
/// que sa couleur et son fond, jamais sa graisse : rien ne bouge sous le doigt.
struct Intercalaires: View {
    /// Le retrait du libellé de part et d'autre, dans la tranche.
    static let retrait: CGFloat = 4

    let pages: [PageDeNavigation]
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @Environment(\.displayScale) private var echelle
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    /// La tranche s'élargit avec le texte, jusqu'à la taille où les libellés se plafonnent.
    @ScaledMetric(relativeTo: .caption2) private var largeur = Mise.tranche

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                ForEach(pages) { page in
                    intercalaire(page.id, libelle: page.libelle, symbole: Pictogrammes.symbole(page.icone))
                }
                Divider().padding(.vertical)
                ForEach(EntreeFixe.allCases) { fixe in
                    intercalaire(fixe.rawValue, libelle: fixe.libelle, symbole: fixe.symbole)
                }
            }
            .padding(.vertical)
        }
        .scrollIndicators(.hidden)
        .frame(width: largeur)
        .background(palette.surface)
        // Le filet qui sépare la tranche de la page ; l'intercalaire ouvert le recouvre.
        .background(alignment: .leading) {
            Rectangle().fill(palette.border).frame(width: 1 / echelle).ignoresSafeArea()
        }
        .sensoryFeedback(.selection, trigger: parcours.onglet)
    }

    private func intercalaire(_ id: String, libelle: String, symbole: String) -> some View {
        let ouvert = parcours.onglet == id
        return Button {
            withAnimation(mouvementReduit ? nil : .snappy) { parcours.onglet = id }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbole).font(.body)
                TexteSansCoupure(texte: libelle, style: .caption2, alignement: .center, plancher: .xSmall)
            }
            .foregroundStyle(ouvert ? palette.primary : palette.textMuted)
            .frame(maxWidth: .infinity, minHeight: Mise.cible)
            .padding(.vertical, 8)
            .padding(.horizontal, Self.retrait)
            .background {
                if ouvert {
                    UnevenRoundedRectangle(topLeadingRadius: Mise.rayon, bottomLeadingRadius: Mise.rayon)
                        .fill(palette.bg)
                        .padding(.leading, -1 / echelle)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(libelle)
        .accessibilityIdentifier("carnet.\(id)")
        .accessibilityAddTraits(ouvert ? .isSelected : [])
    }
}
