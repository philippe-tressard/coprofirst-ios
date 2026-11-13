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
    /// Une correction que l'affaire n'a pas suivie (#187) : remise par la feuille, dite
    /// une fois la feuille fermée (`aDire`) — une alerte ne s'ouvre pas sur une feuille
    /// qui se ferme.
    var nonSuivie: IssueCorrection?
    var aDire: IssueCorrection?

    func feuilleFermee() {
        aDire = nonSuivie
        nonSuivie = nil
    }

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
///
/// Une correction que l'affaire n'a pas suivie (#187) s'annonce par une ALERTE, la
/// feuille fermée : la phrase du serveur telle que servie et, si le compte peut changer
/// l'état, l'état qu'il propose — appliqué par le geste de toujours, une Suite qui
/// change l'état (`ajouterSuite`). L'affaire n'a pas pris l'état choisi : un avis
/// éphémère passerait sans qu'on le lise.
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
            .sheet(item: $choix.aCorriger, onDismiss: feuilleFermee) { suite in
                SuiteFeuille(
                    affaire: affaire, installation: installation, corrigee: suite, envoyee: corrigee,
                    nonSuivie: { choix.nonSuivie = $0 }
                )
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
            .alert(
                TextesSuite.corrigee,
                isPresented: Binding(get: { choix.aDire != nil }, set: { if !$0 { choix.aDire = nil } }),
                presenting: choix.aDire
            ) { issue in
                if let saisie = issue.proposition(pour: affaire),
                    let libelle = issue.libelleProposition(pour: affaire)
                {
                    Button(libelle) { Task { await appliquer(saisie) } }
                    Button(TextesSuite.laisser, role: .cancel) {}
                } else {
                    Button(TextesSuite.compris, role: .cancel) {}
                }
            } message: { issue in
                Text(issue.phrase)
            }
            .avisEphemere(avis)
    }

    private func feuilleFermee() {
        avis.feuilleFermee()
        choix.feuilleFermee()
    }

    /// L'alerte dit déjà « Entrée corrigée » quand l'affaire n'a pas suivi : pas d'avis en plus.
    private func corrigee(_ phrase: String) {
        if choix.nonSuivie == nil { avis.direApresFermeture(phrase) }
        choix.aCorriger = nil
        recharger()
    }

    /// L'état que le serveur propose, appliqué à l'affaire par une Suite qui change l'état.
    private func appliquer(_ saisie: SaisieSuite) async {
        guard let service = parcours.service.gestesAffaire else {
            avis.dire(TextesSuite.indisponible, ton: .error)
            return
        }
        do {
            try await service.ajouterSuite(saisie, a: affaire.id, dans: installation)
            avis.dire(TextesSuite.statutMisAJour)
            recharger()
        } catch {
            avis.dire(ErreurService.depuis(error).phrase, ton: .error)
        }
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
