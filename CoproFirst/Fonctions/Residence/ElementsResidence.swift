// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les pièces que la Fiche et le Carnet partagent : la gouttière d'une carte, son
/// en-tête de rubrique, une capsule neutre, une liste d'annexes. Elles restent dans
/// ce dossier tant qu'un seul menu s'en sert (`swiftui-patterns`, « Composants »).

/// La gouttière d'une carte, comme celle du site (`Gouttiere.svelte`) : la date de
/// l'acte en trois morceaux, puis la nature — pictogramme et abrégé.
struct Gouttiere: View {
    let nature: Nature
    var date: Date?
    @Environment(\.palette) private var palette
    @ScaledMetric(relativeTo: .caption) private var largeur: CGFloat = 52

    /// Les natures que la résidence montre ; pictogramme SF et abrégé du site.
    enum Nature {
        case plan, reglement, assemblee, diagnostic, regle, contrat, intervention, affaire

        var symbole: String {
            switch self {
            case .plan: "square.3.layers.3d"
            case .reglement: "book"
            case .assemblee: "person.3"
            case .diagnostic: "waveform.path.ecg"
            case .regle: "list.bullet.clipboard"
            case .contrat: "doc.text"
            case .intervention: "wrench.and.screwdriver"
            case .affaire: "wrench.adjustable"
            }
        }

        var abrege: String {
            switch self {
            case .plan: "PLAN"
            case .reglement, .regle: "RÈGL."
            case .assemblee: "AG"
            case .diagnostic: "DIAG."
            case .contrat: "CONTRAT"
            case .intervention: "INTERV."
            case .affaire: "AFF."
            }
        }
    }

    @Environment(\.dynamicTypeSize) private var taille

    var body: some View {
        if taille.isAccessibilitySize {
            // Aux très grandes tailles, la gouttière tient sur une ligne, au-dessus du contenu.
            Label {
                Text(
                    [date.map(FormatsDuSite.date), nature.abrege]
                        .compactMap { $0 }.joined(separator: " · "))
            } icon: {
                Image(systemName: nature.symbole)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.textMuted)
        } else {
            colonne
        }
    }

    /// `fmtDate` en trois morceaux — « 2 », « avr. », « 2026 » —, comme `partiesDate`.
    nonisolated static func parties(_ date: Date) -> [String] {
        FormatsDuSite.date(date).split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private var colonne: some View {
        VStack(spacing: 2) {
            if let parties = date.map(Self.parties), parties.count == 3 {
                Text(parties[0]).font(.title3.weight(.semibold)).monospacedDigit()
                Text(parties[1]).font(.caption2)
                Text(parties[2]).font(.caption2).monospacedDigit()
                    .padding(.bottom, 4)
            }
            Image(systemName: nature.symbole).font(.footnote)
            Text(nature.abrege).font(.caption2.weight(.semibold)).tracking(0.4)
        }
        .foregroundStyle(palette.textMuted)
        .frame(width: largeur)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.map(FormatsDuSite.date) ?? "")
    }
}

/// L'en-tête d'une rubrique : son titre (serif de la charte), dit comme un en-tête.
struct EnTeteRubrique: View {
    let titre: String
    var compte: Int?
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titre).font(.titre(.title3)).foregroundStyle(palette.text)
            Spacer()
            if let compte, compte > 0 {
                Text(FormatsDuSite.nombre(compte))
                    .font(.subheadline).monospacedDigit().foregroundStyle(palette.textMuted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Une liste vide, dite par la phrase du site.
struct RubriqueVide: View {
    let texte: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(texte).font(.subheadline).foregroundStyle(palette.textMuted)
    }
}

extension PastilleTeinte {
    /// Une capsule qui DÉCRIT (bâtiment, année, fréquence, numéro) : grise, elle ne
    /// signale pas — `badge-gray` du site.
    static func neutre(_ libelle: String) -> PastilleTeinte {
        PastilleTeinte(libelle: libelle, badge: "badge-gray", compacte: true)
    }
}

/// Les annexes d'une fiche : chacune s'ouvre dans l'aperçu du système.
struct ListeAnnexes: View {
    let annexes: [DocumentResidence]
    @Environment(\.palette) private var palette

    var body: some View {
        if !annexes.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(TextesResidence.annexes).styleLibelle()
                ForEach(annexes) { annexe in
                    NavigationLink(value: DestinationResidence.document(annexe)) {
                        Label(annexe.titre, systemImage: "paperclip")
                            .font(.subheadline)
                            .foregroundStyle(palette.primary)
                            .frame(minHeight: Mise.cible, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Une carte de rubrique : la gouttière à gauche, le contenu à droite.
struct CarteAGouttiere<Contenu: View>: View {
    let gouttiere: Gouttiere
    @ViewBuilder let contenu: () -> Contenu
    @Environment(\.dynamicTypeSize) private var taille

    var body: some View {
        Carte {
            // La rangée passe en colonne aux très grandes tailles (`swiftui-patterns`).
            let disposition =
                taille.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            disposition {
                gouttiere
                VStack(alignment: .leading, spacing: 6) { contenu() }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

extension View {
    /// Une animation d'état, ou aucune quand le mouvement est réduit.
    func animationEtat<V: Equatable>(_ valeur: V, reduit: Bool) -> some View {
        animation(reduit ? nil : .snappy(duration: 0.25), value: valeur)
    }
}
