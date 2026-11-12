// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le trait qui part d'une pastille vers la suivante : plein entre deux étapes engagées,
/// discret avant ce qui est à venir, en pointillé quand le fil reste ouvert.
enum TraitDuRail: Hashable {
    case engage, discret, pointille
}

/// Une rangée du rail : la pastille à gauche, alignée sur la première ligne de `police`,
/// puis le trait jusqu'à la rangée suivante ; le contenu à droite.
struct RangeeDuRail<Contenu: View>: View {
    let etat: EtapeFil.Etat
    let taille: CGFloat
    /// La police de la première ligne du contenu : la pastille se centre sur elle, à toute
    /// taille de texte.
    let police: Font
    let trait: TraitDuRail?
    var enAvant = false
    @ViewBuilder let contenu: () -> Contenu
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Text(verbatim: " ").font(police).hidden()
                    PastilleDuRail(etat: etat, taille: taille, enAvant: enAvant)
                }
                if let trait {
                    LigneDuRail()
                        .stroke(
                            trait == .engage ? palette.primary : palette.border,
                            style: StrokeStyle(lineWidth: Mise.filetRail, dash: trait == .pointille ? [3, 4] : [])
                        )
                        .frame(width: Mise.filetRail)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: Mise.jalon)
            .accessibilityHidden(true)
            contenu()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// La pastille d'une étape : pleine pour le réalisé, un anneau sinon.
private struct PastilleDuRail: View {
    let etat: EtapeFil.Etat
    let taille: CGFloat
    let enAvant: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        let teinte = etat == .aVenir ? palette.textMuted : palette.primary
        ZStack {
            Circle().fill(etat == .realise ? teinte : palette.surface)
            Circle().strokeBorder(teinte, lineWidth: Mise.filetRail)
        }
        .frame(width: taille, height: taille)
        .background {
            // Le halo de l'élément ouvert, comme la pastille courante de la maquette.
            if enAvant {
                Circle().fill(palette.primaryLight).padding(-taille / 2)
            }
        }
    }
}

private struct LigneDuRail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { trace in
            trace.move(to: CGPoint(x: rect.midX, y: rect.minY))
            trace.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
    }
}

extension TraitDuRail {
    /// Le trait sous la rangée `index` d'une suite d'états : rien sous la dernière, sauf
    /// le pointillé d'un fil qui reste ouvert.
    static func sous(_ index: Int, de etats: [EtapeFil.Etat], ouvert: Bool = false) -> TraitDuRail? {
        guard index < etats.count - 1 else { return ouvert ? .pointille : nil }
        return etats[index] != .aVenir && etats[index + 1] != .aVenir ? .engage : .discret
    }
}
