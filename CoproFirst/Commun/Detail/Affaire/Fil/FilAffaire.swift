// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le fil d'une affaire (#178, maquette A du 12/11/2026) : ses sections — La demande, La
/// suite, Comptes rendus, La synthèse (`EtapeFil.du`) — sur un rail, chacune avec ses
/// éléments en retrait sur un rail à elle. Pastille pleine pour le réalisé. La suite et
/// les comptes rendus se plient ; pliés, ils gardent leur ligne de résumé.
struct FilAffaire: View {
    let affaire: DetailAffaire
    let installation: Installation
    @State private var depliage = DepliageDuFil()
    @Environment(\.palette) private var palette

    var body: some View {
        let etapes = EtapeFil.du(affaire)
        let etats = etapes.map(\.etat)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(etapes.enumerated()), id: \.element.id) { index, etape in
                RangeeDuRail(
                    etat: etape.etat, taille: Mise.jalon, police: .titre(.title3),
                    trait: TraitDuRail.sous(index, de: etats)
                ) {
                    section(etape)
                }
            }
        }
    }

    private func section(_ etape: EtapeFil) -> some View {
        let pliee = etape.pliable && depliage.estPliee(etape.cle)
        return VStack(alignment: .leading, spacing: 10) {
            entete(etape, pliee: pliee)
            if etape.cle == .demande {
                demande
            } else if !pliee && !etape.elements.isEmpty {
                let etats = etape.elements.map { $0.realise ? EtapeFil.Etat.realise : .enCours }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(etape.elements.enumerated()), id: \.element.id) { index, element in
                        RangeeDuRail(
                            etat: etats[index], taille: Mise.jalonSecondaire, police: .subheadline,
                            trait: TraitDuRail.sous(index, de: etats, ouvert: etape.ouverteALaSuite),
                            enAvant: depliage.estOuvert(element.id)
                        ) {
                            ElementDuFilView(element: element, depliage: depliage, installation: installation)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.bottom, 18)
    }

    private func entete(_ etape: EtapeFil, pliee: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(etape.titre)
                    .font(.titre(.title3))
                    .foregroundStyle(etape.etat == .aVenir ? palette.textMuted : palette.text)
                Spacer(minLength: 8)
                if etape.pliable {
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.textMuted)
                        .rotationEffect(.degrees(pliee ? 0 : 180))
                }
            }
            Text(etape.meta).font(.subheadline).foregroundStyle(palette.textMuted)
            if pliee, let resume = etape.resumePlie {
                Text(resume).font(.subheadline).foregroundStyle(palette.textMuted).lineLimit(2)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("fil.etape.\(etape.cle.rawValue)")
        .accessibilityValue(etape.pliable ? (pliee ? "Repliée" : "Dépliée") : "")
        .onTapGesture { if etape.pliable { depliage.basculerPli(etape.cle) } }
        .accessibilityAction { if etape.pliable { depliage.basculerPli(etape.cle) } }
    }

    /// La demande : sa description et ses pièces, toujours lisibles.
    private var demande: some View {
        VStack(alignment: .leading, spacing: 14) {
            TexteRiche(html: affaire.description)
                .font(.body)
                .foregroundStyle(palette.text)
                .tint(palette.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            PiecesJointesView(pieces: affaire.pieces, installation: installation)
        }
    }
}
