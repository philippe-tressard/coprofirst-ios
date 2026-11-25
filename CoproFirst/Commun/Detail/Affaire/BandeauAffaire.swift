// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

/// Le bandeau d'une affaire : la rangée d'icônes du site (`ActionsTicket`), rendue en
/// barre d'outils du bas — le matériau du système (verre sous iOS 26), qui laisse
/// défiler le texte dessous, comme Mail. Une icône par geste que le serveur ouvre à CE
/// lecteur (`GesteAffaire.offerts`), un libellé pour VoiceOver et l'appui long.
struct BandeauAffaire: ViewModifier {
    let affaire: DetailAffaire
    let installation: Installation
    let recharger: () -> Void
    @Environment(Parcours.self) private var parcours
    /// À côté d'une liste (iPad), la barre du bas est celle de toute la colonne de la page :
    /// le bandeau se pose au bas de SA colonne (`ColonneDeFiche`).
    @Environment(\.dansLaColonneDeFiche) private var dansLaColonne
    @Environment(\.palette) private var palette
    @State private var feuille: GesteAffaire?
    @State private var aSignaler: DetailAffaire?
    @State private var avis = AvisDuGeste()
    @State private var enCours = false

    func body(content: Content) -> some View {
        let conseil = DroitsOnglet(profil: parcours.ouverteAJour?.profil).cs
        let gestes = GesteAffaire.offerts(
            pour: affaire, conseil: conseil, moderation: installation.sert(.plancher))
        Group {
            if dansLaColonne {
                content.safeAreaInset(edge: .bottom, spacing: 0) {
                    HStack { boutons(gestes) }
                        .padding(.horizontal, Mise.marge)
                        .frame(minHeight: Mise.cible)
                        .background(.bar)
                        .overlay(alignment: .top) { Divider() }
                }
            } else {
                content.toolbar {
                    // Réparties sur la largeur, sous le pouce — la même mise en page sur tous
                    // les iPhone, l'iPhone Duo déplié compris : seule la taille change.
                    ToolbarItemGroup(placement: .bottomBar) { boutons(gestes) }
                }
            }
        }
            .sheet(item: $feuille, onDismiss: avis.feuilleFermee) { geste in
                feuille(geste)
                    .presentationDragIndicator(.visible)
            }
            .signalementAuConseil($aSignaler) { affaire, motif in Task { await signaler(affaire, motif) } }
            .avisEphemere(avis)
    }

    @ViewBuilder
    private func boutons(_ gestes: [GesteAffaire]) -> some View {
        ForEach(gestes) { geste in
            if geste != gestes.first { Spacer() }
            bouton(geste)
                .accessibilityIdentifier("affaire.\(geste.rawValue)")
        }
    }

    @ViewBuilder
    private func feuille(_ geste: GesteAffaire) -> some View {
        switch geste {
        case .suite:
            SuiteFeuille(affaire: affaire, installation: installation, envoyee: envoyee)
                .feuilleACrans()
        case .modifier:
            // Tous les champs de l'affaire : la feuille s'ouvre en grand.
            ModifierAffaireFeuille(affaire: affaire, installation: installation, envoyee: envoyee)
        default:
            RepondreFeuille(affaire: affaire, installation: installation) { envoyee("Réponse envoyée") }
                .feuilleACrans()
        }
    }

    @ViewBuilder
    private func bouton(_ geste: GesteAffaire) -> some View {
        // Dans la colonne de fiche, hors d'une barre du système : l'icône seule (le libellé
        // reste à VoiceOver et à l'appui long) et une cible de 44 pt, comme en barre.
        let icone = Label(geste.libelle, systemImage: geste.symbole)
            .labelStyle(.iconOnly)
            .frame(minWidth: dansLaColonne ? Mise.cible : nil, minHeight: dansLaColonne ? Mise.cible : nil)
            .contentShape(.rect)
        switch geste {
        case .lien:
            // Un toucher COPIE, comme le site (`BoutonLien`) ; l'appui long offre le partage.
            if let adresse {
                Menu {
                    ShareLink(item: adresse) { Label("Partager…", systemImage: "square.and.arrow.up") }
                } label: {
                    icone
                } primaryAction: {
                    UIPasteboard.general.url = adresse
                    avis.dire("Lien copié")
                }
            }
        case .options:
            Menu {
                ForEach(OptionAffaire.toutes) { option in
                    Toggle(isOn: reglage(option)) { Label(option.etat, systemImage: option.symbole) }
                }
            } label: {
                icone
            }
            .disabled(enCours)
            .gesteEnLigne()
        case .archiver:
            Button { Task { await archiver() } } label: { icone }
                .disabled(enCours)
                .gesteEnLigne()
        case .signaler:
            Button { aSignaler = affaire } label: { icone }
                .gesteEnLigne()
        case .repondre, .suite, .modifier:
            Button { feuille = geste } label: { icone }
                .gesteEnLigne()
        }
    }

    /// L'adresse de la page de l'affaire — celle de `lien_ticket()` côté serveur.
    private var adresse: URL? { CheminDuSite.adresse(affaire: affaire.id, sur: installation.adresse) }

    private func envoyee(_ phrase: String) {
        avis.direApresFermeture(phrase)
        feuille = nil
        recharger()
    }

    private func reglage(_ option: OptionAffaire) -> Binding<Bool> {
        Binding(
            get: { option.active(dans: affaire) },
            set: { active in
                Task {
                    await geste(active ? option.etat : "\(option.etat) : retiré") { service in
                        try await service.regler(option, active: active, de: affaire.id, dans: installation)
                    }
                }
            })
    }

    private func archiver() async {
        await geste("Affaire archivée — elle rejoint l'onglet Archives") { service in
            try await service.archiverAffaire(affaire.id, dans: installation)
        }
    }

    /// 🚩 : rien ne change à l'affaire, l'avis le confirme (#286).
    private func signaler(_ affaire: DetailAffaire, _ motif: String) async {
        await avis.agir(avec: parcours.service.signalements, reussite: TextesSignalement.transmis) {
            try await $0.signalerAuConseil(.affaire(affaire.id), motif: motif, dans: installation)
        }
    }

    /// Un geste sans feuille : envoyé, annoncé, puis l'affaire relue.
    private func geste(_ phrase: String, _ envoi: (any ServiceGestesAffaire) async throws -> Void) async {
        enCours = true
        defer { enCours = false }
        await avis.agir(avec: parcours.service.gestesAffaire, reussite: phrase, apres: recharger, envoi)
    }
}

extension View {
    func bandeauAffaire(
        _ affaire: DetailAffaire, installation: Installation, recharger: @escaping () -> Void
    ) -> some View {
        modifier(BandeauAffaire(affaire: affaire, installation: installation, recharger: recharger))
    }
}
