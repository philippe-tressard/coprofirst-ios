// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Une RÉPARTITION en barres découpées selon l'autre axe (`BarresCroisees.svelte`) :
/// la longueur d'une barre est son nombre, rapporté à la plus grande ; ses tranches la
/// remplissent, chacune à sa part, de la teinte que le serveur leur choisit. Le nombre
/// s'écrit en bout de barre, la légende nomme chaque tranche : la couleur ne porte
/// jamais l'information seule, et VoiceOver lit « Bât. A : 3 ».
struct RepartitionCroisee: View {
    let titre: String
    let barres: [Repartition]
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var taille
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @State private var deployee = false

    var body: some View {
        Carte {
            VStack(alignment: .leading, spacing: 12) {
                Text(titre).styleLibelle()
                ForEach(barres) { barre in
                    ligne(barre)
                }
                legende
            }
        }
        .onAppear {
            withAnimation(mouvementReduit ? nil : .smooth(duration: 0.5).delay(0.1)) { deployee = true }
        }
    }

    private var plusGrand: Int { max(1, barres.map(\.nombre).max() ?? 1) }

    private func ligne(_ barre: Repartition) -> some View {
        let disposition =
            taille.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 10))
        return disposition {
            Text(barre.libelle)
                .font(.subheadline)
                .foregroundStyle(palette.text)
                .frame(width: taille.isAccessibilitySize ? nil : 118, alignment: .leading)
                .lineLimit(taille.isAccessibilitySize ? nil : 2)
            HStack(spacing: 8) {
                piste(barre)
                Text(FormatsDuSite.nombre(barre.nombre))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.text)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(barre.libelle) : \(FormatsDuSite.nombre(barre.nombre))"
                + barre.tranches.map { ", \($0.libelle) \(FormatsDuSite.nombre($0.nombre))" }.joined())
    }

    /// La piste, et la part remplie : les tranches, séparées d'un filet de 2 points.
    private func piste(_ barre: Repartition) -> some View {
        GeometryReader { geo in
            let largeur = geo.size.width * CGFloat(barre.nombre) / CGFloat(plusGrand) * (deployee ? 1 : 0)
            HStack(spacing: 2) {
                ForEach(barre.tranches) { tranche in
                    TeinteDeTranche(teinte: tranche.teinte)
                        .frame(width: max(0, (largeur - CGFloat(barre.tranches.count - 1) * 2)
                            * CGFloat(tranche.nombre) / CGFloat(max(1, barre.nombre))))
                }
            }
            .frame(width: largeur, alignment: .leading)
            .clipShape(.rect(cornerRadius: 4, style: .continuous))
        }
        .frame(height: 14)
        .background(palette.neutreFond, in: .rect(cornerRadius: 4, style: .continuous))
    }

    /// Chaque tranche nommée une fois, dans l'ordre où elles apparaissent.
    private var legende: some View {
        var vues: Set<String> = []
        let tranches = barres.flatMap(\.tranches).filter { vues.insert($0.cle).inserted }
        return FlowLegende(tranches: tranches)
            .accessibilityHidden(true)
    }
}

/// La légende : une pastille et un nom par tranche, qui passent à la ligne.
private struct FlowLegende: View {
    let tranches: [Repartition.Tranche]
    @Environment(\.palette) private var palette

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { elements }
            VStack(alignment: .leading, spacing: 6) { elements }
        }
    }

    @ViewBuilder private var elements: some View {
        ForEach(tranches) { tranche in
            HStack(spacing: 6) {
                TeinteDeTranche(teinte: tranche.teinte)
                    .frame(width: 10, height: 10)
                    .clipShape(.rect(cornerRadius: 2))
                Text(tranche.libelle).font(.caption).foregroundStyle(palette.textMuted)
            }
        }
    }
}

/// Une tranche peinte : un aplat, ou des hachures quand la table en donne deux teintes.
private struct TeinteDeTranche: View {
    let teinte: String?
    @Environment(\.palette) private var palette

    var body: some View {
        let couleurs = (teinte.flatMap { TablesReporting.tranches[$0] } ?? [.palette(\.textMuted)])
            .map { $0.couleur(palette) }
        if couleurs.count > 1 {
            Canvas { contexte, taille in
                contexte.fill(Path(CGRect(origin: .zero, size: taille)), with: .color(couleurs[1]))
                var trait = Path()
                var x: CGFloat = -taille.height
                while x < taille.width {
                    trait.move(to: CGPoint(x: x, y: taille.height))
                    trait.addLine(to: CGPoint(x: x + taille.height, y: 0))
                    x += 5
                }
                contexte.stroke(trait, with: .color(couleurs[0]), lineWidth: 2)
            }
        } else {
            Rectangle().fill(couleurs.first ?? palette.textMuted)
        }
    }
}
