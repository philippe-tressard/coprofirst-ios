// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Observation
import SwiftUI

/// « Télémétrie » (onglet `telemetry`) : qui utilise quoi, et quand — quatre vues, le
/// filtre « sans le gestionnaire du site » quand le serveur le propose, puis les nombres
/// clés, le graphe, les pages et les utilisateurs actifs. Le reste se lit sur le site.
struct OngletTelemetrie: OngletDePage {
    let contexte: ContexteOnglet
    @State private var etat = EtatTelemetrie()
    @Environment(\.palette) private var palette

    init(contexte: ContexteOnglet) { self.contexte = contexte }

    var body: some View {
        if let service = contexte.serviceTelemetrie {
            VStack(alignment: .leading, spacing: 16) {
                vues(service)
                contenu(service)
                RenvoiAuSite(
                    texte: TextesTelemetrie.surLeSite, onglet: "telemetry", adresse: contexte.installation.adresse)
            }
            .task(id: contexte.actualisation) { await etat.charger(service, contexte.installation) }
        } else {
            MessageErreur(texte: TextesAdmin.serviceAbsent)
        }
    }

    private func vues(_ service: any ServiceTelemetrie) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(PorteeTelemetrie.allCases) { portee in
                        Pastille(libelle: TextesTelemetrie.vue(portee), retenue: etat.portee == portee) {
                            Task { await etat.choisir(portee, service, contexte.installation) }
                        }
                        .accessibilityIdentifier("admin.telemetrie.vue.\(portee.rawValue)")
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            if let filtre = etat.tableau?.filtreGestionnaire {
                if filtre.propose {
                    Toggle(
                        TextesTelemetrie.sansGestionnaire,
                        isOn: Binding { etat.sansGestionnaire } set: { sans in
                            Task { await etat.filtrer(sans, service, contexte.installation) }
                        }
                    )
                    .tint(palette.primaryPlein)
                    .accessibilityIdentifier("admin.telemetrie.filtre")
                }
                if !filtre.gestionnaireDesigne {
                    aide(TextesTelemetrie.aucunGestionnaire)
                }
                if filtre.applique == "sans" {
                    aide(TextesTelemetrie.filtreApplique(jusquAu: filtre.nonDistingueJusquAu))
                }
            }
        }
    }

    @ViewBuilder
    private func contenu(_ service: any ServiceTelemetrie) -> some View {
        switch etat.phase {
        case .chargement:
            ProgressView(TextesTelemetrie.chargement).frame(maxWidth: .infinity).padding(.vertical, 32)
        case .erreur(let phrase):
            MessageErreur(texte: phrase) { Task { await etat.charger(service, contexte.installation) } }
        case .pret:
            if let tableau = etat.tableau, (tableau.kpi.vues ?? 0) > 0 || !tableau.chart.isEmpty {
                TableauDeFrequentation(tableau: tableau, portee: etat.portee)
                    .opacity(etat.enCours ? 0.5 : 1)
                    .animation(.smooth(duration: 0.2), value: etat.enCours)
            } else {
                ContentUnavailableView(
                    TextesTelemetrie.vide, systemImage: "chart.bar",
                    description: Text(TextesTelemetrie.videMessage))
            }
        }
    }

    private func aide(_ texte: String) -> some View {
        Text(texte).font(.footnote).foregroundStyle(palette.textMuted).fixedSize(horizontal: false, vertical: true)
    }
}

/// L'état de « Télémétrie » : la vue, le filtre, et le tableau lu pour eux. Un échec
/// écarte le tableau précédent : affiché sous une autre vue, il passerait pour elle.
@MainActor
@Observable
final class EtatTelemetrie {
    private(set) var phase = PhaseFile.chargement
    private(set) var tableau: TableauTelemetrie?
    private(set) var portee = PorteeTelemetrie.jour
    private(set) var sansGestionnaire = false
    /// Une relecture après un changement de vue : l'ancien tableau reste, atténué.
    private(set) var enCours = false

    func charger(_ service: any ServiceTelemetrie, _ installation: Installation) async {
        enCours = true
        defer { enCours = false }
        do {
            let lu = try await service.tableauTelemetrie(
                installation, portee: portee, sansGestionnaire: sansGestionnaire)
            tableau = lu
            // Le serveur applique « avec » à un « sans » qui ne changerait rien.
            sansGestionnaire = lu.filtreGestionnaire.applique == "sans"
            phase = .pret
        } catch {
            tableau = nil
            phase = .erreur(ErreurService.phrase(error, sinon: TextesTelemetrie.erreur))
        }
    }

    func choisir(_ portee: PorteeTelemetrie, _ service: any ServiceTelemetrie, _ installation: Installation) async {
        guard portee != self.portee else { return }
        self.portee = portee
        await charger(service, installation)
    }

    func filtrer(_ sans: Bool, _ service: any ServiceTelemetrie, _ installation: Installation) async {
        sansGestionnaire = sans
        await charger(service, installation)
    }
}
