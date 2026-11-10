// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Charts
import SwiftUI

/// « Indicateurs et fréquentation » (`FrequentationTelemetrie.svelte`) : les nombres clés
/// de la vue, ses records, le graphe titré par le serveur, les pages et les utilisateurs.
struct TableauDeFrequentation: View {
    let tableau: TableauTelemetrie
    let portee: PorteeTelemetrie
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var taille

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            LazyVGrid(columns: colonnes, alignment: .leading, spacing: 10) {
                ForEach(TextesTelemetrie.indicateurs(tableau.kpi, portee), id: \.libelle) { indicateur in
                    Indicateur(valeur: indicateur.valeur, libelle: indicateur.libelle)
                }
            }
            .accessibilityIdentifier("admin.telemetrie.indicateurs")
            graphe
            if !tableau.topPages.isEmpty { pages }
            if !tableau.topUsers.isEmpty { utilisateurs }
        }
    }

    private var colonnes: [GridItem] {
        taille.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 150), spacing: 10)]
    }

    private var graphe: some View {
        Carte {
            VStack(alignment: .leading, spacing: 12) {
                Text(tableau.chartLabel).font(.headline).foregroundStyle(palette.text)
                Chart(tableau.chart) { baton in
                    BarMark(
                        x: .value(TextesTelemetrie.periode, TextesTelemetrie.etiquette(baton.label, portee)),
                        y: .value(TextesTelemetrie.vuesAxe, baton.total)
                    )
                    .foregroundStyle(palette.primary.gradient)
                    .cornerRadius(3)
                    .accessibilityLabel(TextesTelemetrie.libelle(baton.label, portee))
                    .accessibilityValue(TextesTelemetrie.valeur(baton))
                }
                .chartYAxis {
                    AxisMarks { valeur in
                        AxisGridLine().foregroundStyle(palette.border)
                        AxisValueLabel { Text(FormatsDuSite.nombre(valeur.as(Int.self))) }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                        AxisValueLabel().foregroundStyle(palette.textMuted)
                    }
                }
                .frame(height: 180)
            }
        }
        .accessibilityIdentifier("admin.telemetrie.graphe")
    }

    private var pages: some View {
        Section {
            Carte {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(tableau.topPages.enumerated()), id: \.element.id) { rang, page in
                        if rang > 0 { Divider().overlay(palette.border) }
                        LabeledContent {
                            Text(TextesTelemetrie.vuesEtUniques(page.total, page.uniques))
                                .monospacedDigit()
                                .foregroundStyle(palette.textMuted)
                        } label: {
                            Text(page.page).font(.subheadline.monospaced()).foregroundStyle(palette.text)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        } header: {
            titre(TextesTelemetrie.pagesVues)
        }
    }

    private var utilisateurs: some View {
        Section {
            Carte {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(tableau.topUsers.enumerated()), id: \.offset) { rang, utilisateur in
                        if rang > 0 { Divider().overlay(palette.border) }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(utilisateur.nom).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                            Text(
                                [
                                    utilisateur.statut.map(RolesUtilisateur.libelleStatut),
                                    TextesTelemetrie.vuesEtPages(utilisateur.total, utilisateur.pages),
                                ].compactMap { $0 }.joined(separator: " · ")
                            )
                            .font(.footnote).foregroundStyle(palette.textMuted)
                            if let derniere = utilisateur.derniereConnexion {
                                Text(TextesTelemetrie.derniereConnexion(FormatsDuSite.dateHeure(derniere)))
                                    .font(.footnote).foregroundStyle(palette.textMuted)
                            }
                        }
                        .padding(.vertical, 8)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        } header: {
            titre(TextesTelemetrie.utilisateursActifs)
        }
    }

    private func titre(_ texte: String) -> some View {
        Text(texte).font(.titre(.title3)).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
    }
}

/// Un nombre clé : la valeur en grand, son libellé dessous.
private struct Indicateur: View {
    let valeur: String
    let libelle: String
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(valeur)
                .font(.titre(.title2))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(palette.text)
            Text(libelle)
                .font(.footnote)
                .foregroundStyle(palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(palette.surface, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous).strokeBorder(palette.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
