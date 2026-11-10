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
    @State private var feuille: GesteAffaire?
    @State private var avis = AvisDuGeste()
    @State private var enCours = false

    func body(content: Content) -> some View {
        let conseil = DroitsOnglet(profil: parcours.ouverteAJour?.profil).cs
        let gestes = GesteAffaire.offerts(pour: affaire, conseil: conseil)
        content
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    ForEach(gestes) { geste in
                        if geste != gestes.first { Spacer() }
                        bouton(geste)
                            .accessibilityIdentifier("affaire.\(geste.rawValue)")
                    }
                }
            }
            .sheet(item: $feuille, onDismiss: avis.feuilleFermee) { geste in
                feuille(geste)
                    .presentationDragIndicator(.visible)
            }
            .avisEphemere(avis)
    }

    @ViewBuilder
    private func feuille(_ geste: GesteAffaire) -> some View {
        switch geste {
        case .suite:
            SuiteFeuille(affaire: affaire, installation: installation, envoyee: envoyee)
                .presentationDetents([.medium, .large])
        case .modifier:
            // Tous les champs de l'affaire : la feuille s'ouvre en grand.
            ModifierAffaireFeuille(affaire: affaire, installation: installation, envoyee: envoyee)
        default:
            RepondreFeuille(affaire: affaire, installation: installation) { envoyee("Réponse envoyée") }
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func bouton(_ geste: GesteAffaire) -> some View {
        let icone = Label(geste.libelle, systemImage: geste.symbole)
        switch geste {
        case .lien:
            // Un toucher COPIE, comme le site (`BoutonLien`) ; l'appui long offre le partage.
            Menu {
                ShareLink(item: adresse) { Label("Partager…", systemImage: "square.and.arrow.up") }
            } label: {
                icone
            } primaryAction: {
                UIPasteboard.general.url = adresse
                avis.dire("Lien copié")
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
        case .archiver:
            Button { Task { await archiver() } } label: { icone }
                .disabled(enCours)
        case .repondre, .suite, .modifier:
            Button { feuille = geste } label: { icone }
        }
    }

    /// L'adresse de la page de l'affaire — celle de `lien_ticket()` côté serveur.
    private var adresse: URL { installation.adresse.appending(path: "tickets/\(affaire.id)") }

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

    /// Un geste sans feuille : envoyé, annoncé, puis l'affaire relue.
    private func geste(_ phrase: String, _ envoi: (any ServiceGestesAffaire) async throws -> Void) async {
        guard let service = parcours.service.gestesAffaire else {
            avis.dire("Ce geste n'est pas disponible ici.", ton: .error)
            return
        }
        enCours = true
        defer { enCours = false }
        do {
            try await envoi(service)
            avis.dire(phrase)
            recharger()
        } catch {
            avis.dire(ErreurService.depuis(error).phrase, ton: .error)
        }
    }
}

extension View {
    func bandeauAffaire(
        _ affaire: DetailAffaire, installation: Installation, recharger: @escaping () -> Void
    ) -> some View {
        modifier(BandeauAffaire(affaire: affaire, installation: installation, recharger: recharger))
    }
}
