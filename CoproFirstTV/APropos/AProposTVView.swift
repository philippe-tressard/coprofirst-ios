// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « À propos » de l'écran de hall (#320) : où obtenir le code de l'app et sous quelle
/// licence (condition 3 b de la permission App Store), puis les paquets qu'elle embarque et
/// leurs textes entiers (Apache-2.0 §4) — ce que l'iPhone dit dans Plus › À propos.
///
/// Les mots et la liste sont ceux de l'iPhone (`SourceDeLApp`, `ComposantsTiers.paquets`) ;
/// la forme est celle de tvOS : pas de lien (aucun navigateur), l'adresse en clair, lue de loin.
struct AProposTVView: View {
    @State private var chemin = Self.cheminAuLancement
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack(path: $chemin) {
            ScrollView {
                VStack(alignment: .leading, spacing: Mise.marge * 2) {
                    source
                    composants
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Mise.marge * 3)
            }
            .background(palette.bg)
            .navigationTitle(EcranDeHall.aPropos)
            .navigationDestination(for: ComposantTiers.ID.self) { nom in
                if let composant = ComposantsTiers.paquets.first(where: { $0.id == nom }) {
                    LicencesTiercesTVView(composant: composant)
                }
            }
        }
        .tint(palette.primary)
    }

    #if DEBUG
    /// `-composant <nom>` : ses textes ouverts dès le lancement, pour les captures.
    private static var cheminAuLancement: [ComposantTiers.ID] {
        LancementTVSimule.composant(ProcessInfo.processInfo.arguments).map { [$0] } ?? []
    }
    #else
    private static let cheminAuLancement: [ComposantTiers.ID] = []
    #endif

    /// L'adresse du dépôt, en clair, puis la licence.
    private var source: some View {
        VStack(alignment: .leading, spacing: MiseTV.ecart) {
            Text(EcranDeHall.versionApp(SourceDeLApp.version()))
                .styleLibelle()
                .accessibilityIdentifier("hall.a-propos.version")
            Text(SourceDeLApp.libelle)
                .font(.titre(.title2))
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
            // Sur une ligne : coupée, l'adresse se lirait comme deux. Elle déborde la mesure,
            // pas l'écran (52 signes en chasse fixe).
            Text(SourceDeLApp.depot)
                .font(.title3.monospaced())
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityIdentifier("hall.a-propos.depot")
            Text(SourceDeLApp.licence)
                .font(.body)
                .foregroundStyle(palette.textMuted)
                .accessibilityIdentifier("hall.a-propos.licence")
        }
        .frame(maxWidth: MiseTV.mesure, alignment: .leading)
    }

    /// Un bouton par paquet : sur tvOS, le focus se pose sur un bouton, jamais sur un texte seul.
    private var composants: some View {
        VStack(alignment: .leading, spacing: MiseTV.ecart) {
            Text(EcranDeHall.composantsTiers)
                .styleLibelle()
                .accessibilityAddTraits(.isHeader)
            ForEach(ComposantsTiers.paquets) { composant in
                // Le nom et la licence dans la couleur du bouton, qui suit le focus : la valeur
                // d'un `LabeledContent` gardait son gris sur le fond du bouton focalisé.
                NavigationLink(value: composant.id) {
                    HStack {
                        Text(composant.nom)
                        Spacer()
                        Text(composant.licences)
                    }
                    .frame(maxWidth: MiseTV.mesure)
                }
                .accessibilityIdentifier("hall.composant.\(composant.nom)")
            }
        }
    }
}

/// Un paquet et ses textes entiers — l'avis, puis la licence —, un paragraphe à la fois : sur
/// tvOS, une page défile en suivant le focus, et un texte d'un seul tenant ne défilerait pas
/// jusqu'à sa fin.
struct LicencesTiercesTVView: View {
    let composant: ComposantTiers
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: MiseTV.ecart) {
                Text(composant.role)
                    .font(.headline)
                    .foregroundStyle(palette.text)
                ForEach(Array(paragraphes.enumerated()), id: \.offset) { _, paragraphe in
                    ParagrapheTV(texte: paragraphe)
                }
            }
            .frame(maxWidth: MiseTV.mesure + Mise.marge * 2, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Mise.marge * 2)
        }
        .background(palette.bg)
        .navigationTitle(composant.nom)
    }

    /// Les textes du paquet, coupés à leurs lignes vides.
    private var paragraphes: [String] {
        composant.lus().flatMap { texte in
            texte.components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }
}

/// Un paragraphe qui prend le focus, et le montre par un fond : on sait où l'on en est.
private struct ParagrapheTV: View {
    let texte: String
    @FocusState private var lu: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        Text(texte)
            .font(.caption.monospaced())
            .foregroundStyle(lu ? palette.text : palette.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Mise.marge)
            .background(lu ? palette.surface : .clear, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
            .focusable()
            .focused($lu)
            .animation(.snappy, value: lu)
    }
}

/// « À propos », offert à chaque étape de l'écran de hall : un bouton, et l'écran entier.
struct BoutonAProposTV: View {
    @State private var ouvert = Self.ouvertAuLancement

    #if DEBUG
    /// `-a-propos` : l'écran ouvert dès le lancement, pour les captures (`LancementTVSimule`).
    private static var ouvertAuLancement: Bool { LancementTVSimule.aPropos(ProcessInfo.processInfo.arguments) }
    #else
    private static let ouvertAuLancement = false
    #endif

    var body: some View {
        Button(EcranDeHall.aPropos) { ouvert = true }
            .accessibilityIdentifier("hall.a-propos")
            .modifier(AProposTVPresente(ouvert: $ouvert))
    }
}

/// L'écran « À propos » par-dessus l'écran de hall, à sa palette et à son thème ; Menu le referme.
struct AProposTVPresente: ViewModifier {
    @Binding var ouvert: Bool
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var theme

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $ouvert) {
            AProposTVView()
                .environment(\.palette, palette)
                .environment(\.colorScheme, theme)
        }
    }
}
