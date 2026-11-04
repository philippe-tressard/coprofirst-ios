// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'onglet Archives : les affaires closes et les actualités passées, sur trois
/// ans, par année — chaque année se replie (`ArchivesParAnnee` du site).
struct ArchivesAffaires: View {
    @Bindable var etat: EtatAffaires
    let installation: Installation
    let service: (any ServiceAffaires)?
    let ouvrir: (Affaire) -> Void
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    /// Les années repliées ; la plus récente s'ouvre d'elle-même.
    @State private var repliees: Set<Int> = []
    @State private var dejaVues: Set<Int> = []

    var body: some View {
        let annees = etat.archives
        List {
            ForEach(annees, id: \.annee) { groupe in
                Section {
                    if !repliees.contains(groupe.annee) {
                        ForEach(groupe.affaires) { affaire in
                            Button {
                                ouvrir(affaire)
                            } label: {
                                CarteAffaire(affaire: affaire, archive: true)
                            }
                            .buttonStyle(StyleCarte())
                            .rangeeDAffaire()
                            .accessibilityIdentifier("archives.carte.\(affaire.numero)")
                        }
                    }
                } header: {
                    enTete(groupe.annee, compte: groupe.affaires.count)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay { etatVide(vide: annees.isEmpty) }
        .refreshable { await etat.charger(installation, avec: service) }
        .onChange(of: annees.map(\.annee), initial: true) { _, liste in
            // Une année qui apparaît se replie, sauf la plus récente : la règle se
            // calcule, elle ne s'écrit pas année par année.
            for annee in liste where !dejaVues.contains(annee) {
                dejaVues.insert(annee)
                if annee != liste.first { repliees.insert(annee) }
            }
        }
    }

    private func enTete(_ annee: Int, compte: Int) -> some View {
        let ouverte = !repliees.contains(annee)
        return Button {
            withAnimation(mouvementReduit ? nil : .snappy) {
                if ouverte { repliees.insert(annee) } else { repliees.remove(annee) }
            }
        } label: {
            HStack(spacing: 10) {
                Text(String(annee))
                    .font(.titre(.title3))
                    .foregroundStyle(palette.text)
                Text(compte, format: .number)
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundStyle(palette.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(palette.neutreFond, in: .capsule)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.textMuted)
                    .rotationEffect(.degrees(ouverte ? 0 : -90))
            }
            .frame(minHeight: Mise.cible)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .textCase(nil)
        .listRowInsets(EdgeInsets(top: 0, leading: Mise.marge, bottom: 0, trailing: Mise.marge))
        .accessibilityLabel("\(annee), \(compte) affaire(s)")
        .accessibilityValue(ouverte ? "dépliée" : "repliée")
        .accessibilityHint(ouverte ? "Replie l'année" : "Déplie l'année")
        .accessibilityIdentifier("archives.annee.\(annee)")
    }

    @ViewBuilder
    private func etatVide(vide: Bool) -> some View {
        switch etat.phase {
        case .chargement:
            ProgressView()
        case .erreur(let erreur):
            ContentUnavailableView {
                Label("Impossible d'afficher les archives", systemImage: "exclamationmark.triangle")
            } description: {
                Text(erreur.phrase)
            } actions: {
                Button("Réessayer") { Task { await etat.charger(installation, avec: service) } }
                    .buttonStyle(.plein)
                    .fixedSize()
            }
        case .pret where vide:
            ContentUnavailableView {
                Label("Aucune archive", systemImage: "archivebox")
            } description: {
                Text("Les affaires closes et les actualités passées rejoignent cet onglet.")
            }
        case .pret:
            EmptyView()
        }
    }
}
