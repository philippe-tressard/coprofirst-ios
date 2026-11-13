// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'entrée de l'Historique qu'un geste vise : tenue par l'écran (`gestesHistorique`),
/// posée par l'entrée touchée (`gestesSuite`). Seul l'écran présente la feuille et la
/// question — posées sur une entrée, elles se multiplieraient avec le fil.
@MainActor @Observable
final class ChoixDeSuite {
    var aCorriger: SuiteAffaire?
    var aSupprimer: SuiteAffaire?

    func choisir(_ geste: GesteSuite, _ suite: SuiteAffaire) {
        switch geste {
        case .modifier: aCorriger = suite
        case .supprimer: aSupprimer = suite
        }
    }
}

/// Les gestes des entrées de l'Historique d'une affaire (#91, #93), comme le site
/// (`RubriqueHistorique.svelte`) : « Modifier la suite » ouvre la feuille de la Suite
/// partie de l'entrée (`SuiteFeuille`), « Supprimer cette entrée » se confirme. Chacun
/// s'annonce par l'avis du geste, puis l'affaire se relit.
struct GestesHistorique: ViewModifier {
    let affaire: DetailAffaire
    let installation: Installation
    let recharger: () -> Void
    @Environment(Parcours.self) private var parcours
    @State private var choix = ChoixDeSuite()
    @State private var avis = AvisDuGeste()

    func body(content: Content) -> some View {
        @Bindable var choix = choix
        content
            .environment(choix)
            .sheet(item: $choix.aCorriger, onDismiss: avis.feuilleFermee) { suite in
                SuiteFeuille(affaire: affaire, installation: installation, corrigee: suite, envoyee: corrigee)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .confirmationDialog(
                TextesSuite.supprimer,
                isPresented: Binding(get: { choix.aSupprimer != nil }, set: { if !$0 { choix.aSupprimer = nil } }),
                titleVisibility: .visible, presenting: choix.aSupprimer
            ) { suite in
                Button(TextesSuite.confirmer, role: .destructive) { Task { await supprimer(suite) } }
                    .gesteEnLigne()
                    .accessibilityIdentifier("historique.confirmerSuppression")
            } message: { suite in
                Text(TextesSuite.question(suite))
            }
            .avisEphemere(avis)
    }

    private func corrigee(_ phrase: String) {
        avis.direApresFermeture(phrase)
        choix.aCorriger = nil
        recharger()
    }

    private func supprimer(_ suite: SuiteAffaire) async {
        guard let service = parcours.service.gestesAffaire else {
            avis.dire(TextesSuite.indisponible, ton: .error)
            return
        }
        do {
            try await service.supprimerSuite(suite.id, de: affaire.id, dans: installation)
            avis.dire(TextesSuite.supprimee)
            recharger()
        } catch {
            avis.dire(ErreurService.depuis(error).phrase, ton: .error)
        }
    }
}

/// Les gestes d'UNE entrée : un bouton « ⋯ » à sa droite, visible — un appui long seul
/// serait un geste caché —, qui ouvre le menu du système ; et les mêmes gestes en
/// actions d'accessibilité de l'entrée, que VoiceOver lit d'un trait. Rien quand le
/// serveur n'en sert aucun, ni hors d'un écran qui les porte (le squelette).
private struct GestesSuite: ViewModifier {
    let suite: SuiteAffaire?
    @Environment(ChoixDeSuite.self) private var choix: ChoixDeSuite?
    @Environment(\.palette) private var palette
    /// La hauteur de la première ligne de l'entrée : le bouton s'y aligne.
    @ScaledMetric(relativeTo: .subheadline) private var ligne: CGFloat = 20

    func body(content: Content) -> some View {
        let gestes = choix == nil ? [] : suite.map(GesteSuite.offerts(pour:)) ?? []
        if let suite, !gestes.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                content
                    .accessibilityActions {
                        ForEach(gestes) { geste in
                            Button(geste.libelle) { choix?.choisir(geste, suite) }
                        }
                    }
                Menu {
                    ForEach(gestes) { geste in
                        Button(role: geste == .supprimer ? .destructive : nil) {
                            choix?.choisir(geste, suite)
                        } label: {
                            Label(geste.libelle, systemImage: geste.symbole)
                        }
                        .accessibilityIdentifier("historique.geste.\(geste.rawValue)")
                    }
                } label: {
                    // Le « ⋯ » des cartes de l'app (`CarteAnnonceHall`). La cible fait 44 pt ;
                    // elle déborde dans la marge de la carte, pour rester sur la première
                    // ligne de l'entrée sans l'épaissir.
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(palette.primary)
                        .frame(minWidth: Mise.cible, minHeight: Mise.cible)
                        .contentShape(.rect)
                        .padding(-max(0, (Mise.cible - ligne) / 2))
                }
                .accessibilityLabel(TextesSuite.gestes)
                .gesteEnLigne()
                .accessibilityIdentifier("historique.gestes.\(suite.id)")
            }
        } else {
            content
        }
    }
}

extension View {
    /// À poser sur l'écran d'une affaire : il présente ce que ses entrées demandent.
    func gestesHistorique(
        _ affaire: DetailAffaire, installation: Installation, recharger: @escaping () -> Void
    ) -> some View {
        modifier(GestesHistorique(affaire: affaire, installation: installation, recharger: recharger))
    }

    /// À poser sur une entrée de la suite, lue d'un trait (`accessibilityElement`) ; rien
    /// sans entrée (un compte rendu, une partie de la synthèse).
    func gestesSuite(_ suite: SuiteAffaire?) -> some View { modifier(GestesSuite(suite: suite)) }
}
