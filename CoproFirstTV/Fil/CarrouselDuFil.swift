// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le reste du Fil, en bas de l'écran (#429) : « Et aussi », puis quatre cartes qui avancent
/// d'une place par cran — la première sort à gauche, une carte entre à droite. Jamais en
/// continu ; avec le mouvement réduit, la rangée change en fondu.
struct CarrouselDuFil: View {
    let diffusion: DiffusionDuFil
    let reduit: Bool
    let espace: Namespace.ID
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(EcranDeHall.etAussi)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .tracking(Mise.approcheLibelle * 2)
                .foregroundStyle(palette.textMuted)
            Group {
                if reduit {
                    rangee.id(diffusion.premiere).transition(.opacity)
                } else {
                    rangee
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: MiseTV.carrousel)
            .clipped()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hall.carrousel")
    }

    private var rangee: some View {
        HStack(spacing: MiseTV.joint) {
            ForEach(diffusion.carrousel) { element in
                let tuile = TuileDuHall.carte(element)
                TuileView(tuile: tuile, diffusion: diffusion)
                    .grandit(tuile.id, dans: espace, enAvant: diffusion.enAvant, reduit: reduit)
                    .frame(width: largeurCarte)
                    .transition(
                        reduit
                            ? .opacity
                            : .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
    }

    /// Quatre cartes et trois joints sur la largeur utile de l'écran (1 760 points).
    private var largeurCarte: CGFloat {
        let places = CGFloat(MiseTV.placesCarrousel)
        return (MiseTV.largeurUtile - MiseTV.joint * (places - 1)) / places
    }
}

/// Une carte du reste du Fil : sa rubrique, son délai ou sa date, son titre, son lieu, ses
/// photos en vignettes, son QR code.
struct CarteDuHallView: View {
    let element: ElementDuHall
    let diffusion: DiffusionDuFil
    @Environment(\.palette) private var palette

    var body: some View {
        let nature = element.nature
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    EnTeteDeTuile(libelle: nature.libelle, icone: nature.icone)
                        .foregroundStyle(palette[keyPath: nature.couleur])
                        .lineLimit(1)
                    Text(element.echeance ?? FormatsDuSite.jourCourt(element.date))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(palette.textMuted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                CodeQRView(adresse: diffusion.adresse(element.lien), cote: MiseTV.codeQRPetit, titre: element.titre)
            }
            Text(element.titre).font(.callout.weight(.semibold)).foregroundStyle(palette.text).lineLimit(2)
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 12) {
                LigneDuLieu(element: element, avecEcheance: false).foregroundStyle(palette.textMuted)
                Spacer(minLength: 0)
                VignettesDuHall(source: .element(element.id), nombre: element.photos, diffusion: diffusion)
            }
        }
        .surfaceDeTuile(palette.surface)
        .overlay(RoundedRectangle(cornerRadius: MiseTV.rayon, style: .continuous).stroke(palette.border))
    }
}

extension View {
    /// La tuile grandit depuis sa place quand elle passe en avant (`matchedGeometryEffect`,
    /// source tant qu'elle est à sa place) et s'efface le temps de l'être. Avec le mouvement
    /// réduit, aucun déplacement : la mise en avant paraît en fondu.
    @ViewBuilder
    func grandit(_ id: String, dans espace: Namespace.ID, enAvant: String?, reduit: Bool) -> some View {
        if reduit {
            opacity(enAvant == id ? 0 : 1)
        } else {
            matchedGeometryEffect(id: id, in: espace, isSource: enAvant != id)
                .opacity(enAvant == id ? 0 : 1)
        }
    }
}
