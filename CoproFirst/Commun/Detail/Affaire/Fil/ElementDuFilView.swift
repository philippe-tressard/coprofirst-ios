// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

/// Un élément sous une section du fil (#178). Plié : un titre, une ligne, un aperçu.
/// Un toucher l'ouvre un instant (`DepliageDuFil.regard`) ; double toucher, appui long
/// (menu) ou action d'accessibilité le gardent ouvert.
///
/// Avec VoiceOver, un toucher le GARDE ouvert : un texte qui se replie seul pendant
/// qu'on le lit ne se lit pas (`standards/11`).
struct ElementDuFilView: View {
    let element: ElementFil
    let depliage: DepliageDuFil
    let installation: Installation
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    var body: some View {
        let ouvert = depliage.estOuvert(element.id)
        let garde = depliage.estGarde(element.id)
        VStack(alignment: .leading, spacing: 8) {
            // Les gestes d'une entrée de la suite (#91, #93) à sa droite, hors du résumé lu d'un trait.
            resume(ouvert: ouvert, garde: garde)
                .gestesSuite(element.suite)
            if ouvert {
                VStack(alignment: .leading, spacing: 8) {
                    if let precise = element.precise {
                        Text(precise).font(.subheadline).foregroundStyle(palette.textMuted)
                    }
                    if let html = element.html, !TexteRiche(html: html).vide {
                        TexteRiche(html: html)
                            .font(.body)
                            .foregroundStyle(palette.text)
                            .tint(palette.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Hors de l'élément lu d'un trait : chaque pièce s'ouvre à part.
                    PiecesJointesView(pieces: element.pieces, installation: installation, format: .compact)
                    if !garde { Regard(duree: depliage.duree) }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(garde ? palette.surface : palette.bg, in: .rect(cornerRadius: Mise.rayon))
                .overlay {
                    if garde {
                        RoundedRectangle(cornerRadius: Mise.rayon).strokeBorder(palette.primary.opacity(0.5))
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.bottom, 12)
    }

    private func resume(ouvert: Bool, garde: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(element.titre)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.text)
                Spacer(minLength: 0)
                if garde {
                    Image(systemName: "pin.fill").font(.caption).foregroundStyle(palette.primary)
                        .accessibilityLabel(TextesFil.garderOuvert)
                }
                if !element.pieces.vide {
                    Image(systemName: "paperclip").font(.caption).foregroundStyle(palette.textMuted)
                        .accessibilityLabel(element.pieces.enClair ?? "")
                }
            }
            if !element.ligne.isEmpty {
                Text(element.ligne).font(.caption).foregroundStyle(palette.textMuted)
            }
            if !ouvert, let apercu = element.apercu {
                Text(apercu).font(.subheadline).foregroundStyle(palette.textMuted).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("fil.element.\(element.id)")
        .onTapGesture(count: 2) { depliage.basculerGarde(element.id) }
        .onTapGesture { voiceOver ? depliage.basculerGarde(element.id) : depliage.toucher(element.id) }
        .accessibilityAction(named: garde ? TextesFil.nePlusGarderOuvert : TextesFil.garderOuvert) {
            depliage.basculerGarde(element.id)
        }
        .contextMenu {
            Button(
                garde ? TextesFil.nePlusGarderOuvert : TextesFil.garderOuvert,
                systemImage: garde ? "pin.slash" : "pin"
            ) { depliage.basculerGarde(element.id) }
            if let html = element.html {
                Button(TextesFil.copier, systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = TexteDuSite.apercu(html)
                }
            }
        }
    }
}

/// Le temps qui reste avant que l'élément se replie : un filet qui se vide.
private struct Regard: View {
    let duree: Duration
    @State private var reste: CGFloat = 1
    @Environment(\.palette) private var palette

    var body: some View {
        Capsule()
            .fill(palette.primary)
            .frame(height: Mise.filetRail)
            .scaleEffect(x: reste, anchor: .leading)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.linear(duration: Double(duree.components.seconds))) { reste = 0 }
            }
    }
}
