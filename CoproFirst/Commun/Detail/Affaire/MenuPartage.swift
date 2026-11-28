// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

/// « Partager » une affaire (#435) — le menu du site (`MenuPartage.svelte`, maquette H,
/// arbitrage n° 89, coprofirst#3164), qui remplace 🔗 : copier le lien, le partager, et pour
/// une affaire datée à venir, « Ajouter à Calendrier » puis « Autre agenda… ».
///
/// - **Ce qui part** dans l'agenda : le rendez-vous que le SERVEUR compose
///   (`GET /tickets/{id}/agenda`), lu à l'ouverture de l'affaire, jamais le texte de l'écran.
/// - **Si l'agenda est proposé** : `agenda_propose`, servi avec l'affaire, ET la porte du
///   contrat 2.15.0 (`installation.sert(.agenda)`) — d'une résidence antérieure, rien.
/// - **Quel agenda par défaut** : celui de l'appareil, Calendrier, par la feuille du système
///   (`FeuilleAgenda`) ; « Autre agenda… » ouvre la page de saisie servie de chacun.
///
/// « Envoyer par courriel » du site (`PartageCourriel`, l'envoi par la résidence) n'est pas
/// dans l'app : « Partager… » ouvre la feuille de partage d'iOS, Mail compris (divergence
/// déclarée, `ux-patterns-ios`).
struct MenuPartage<Icone: View>: View {
    let affaire: DetailAffaire
    let installation: Installation
    let avis: AvisDuGeste
    @ViewBuilder let icone: () -> Icone
    @Environment(Parcours.self) private var parcours
    @State private var enLigne = EtatRendezVous.attente
    @State private var aAjouter: RendezVousAffaire?

    var body: some View {
        // Un séparateur, pas des `Section` : dans la barre du bas, une `Section` du menu fait
        // perdre leur identifiant à ses entrées (constaté au simulateur le 28/11/2026, #435).
        // Sans adresse ni agenda, aucune entrée : pas de menu vide (comme 🔗 avant lui).
        if adresse != nil || Self.agendaOffert(affaire, installation) { menu }
    }

    private var menu: some View {
        Menu {
            if let adresse {
                Button {
                    UIPasteboard.general.url = adresse
                    avis.dire("Lien copié")
                } label: {
                    Label("Copier le lien", systemImage: "link")
                }
                .accessibilityIdentifier("affaire.partager.copier")
                ShareLink(item: adresse) { Label("Partager…", systemImage: "square.and.arrow.up") }
            }
            if Self.agendaOffert(affaire, installation) { agendas }
        } label: {
            icone()
        }
        // Relu quand l'affaire relue change d'avis (`agenda_propose`), pas à chaque rechargement.
        .task(id: [affaire.id, affaire.agendaPropose ? 1 : 0]) { await lire() }
        .sheet(item: $aAjouter) { rendezVous in
            FeuilleAgenda(rendezVous: rendezVous) { aAjouter = nil }
                .ignoresSafeArea()
        }
    }

    /// La règle, écrite une fois : servi par l'affaire ET derrière la porte de sa route.
    static func agendaOffert(_ affaire: DetailAffaire, _ installation: Installation) -> Bool {
        affaire.agendaPropose && installation.sert(.agenda)
    }

    @ViewBuilder
    private var agendas: some View {
        Divider()
        Button {
            Task { await ajouter() }
        } label: {
            Label {
                Text("Ajouter à Calendrier")
                // Ce que précise le site sous l'entrée : l'appareil (`agendaParDefaut`).
                Text(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone")
            } icon: {
                Image(systemName: "calendar.badge.plus")
            }
        }
        .accessibilityIdentifier("affaire.agenda")
        .gesteEnLigne()
        Menu {
            switch enLigne {
            case .lu(let rendezVous):
                ForEach(AgendaEnLigne.allCases) { agenda in
                    if let page = rendezVous.enLigne[agenda] {
                        Link(agenda.libelle, destination: page)
                            .gesteEnLigne()
                    }
                }
            case .attente:
                Text("Préparation du rendez-vous…")
            case .echec(let phrase):
                Text(phrase)
            }
        } label: {
            Label("Autre agenda…", systemImage: "calendar")
        }
        .accessibilityIdentifier("affaire.agenda.autres")
    }

    /// L'adresse de la page de l'affaire — celle de `lien_ticket()` côté serveur.
    private var adresse: URL? { CheminDuSite.adresse(affaire: affaire.id, sur: installation.adresse) }

    /// Le rendez-vous, lu avec l'affaire : « Autre agenda… » a ses pages dès l'ouverture du menu.
    private func lire() async {
        guard Self.agendaOffert(affaire, installation) else { return }
        guard let service = parcours.service.gestesAffaire else {
            enLigne = .echec(EtatRendezVous.indisponibles)
            return
        }
        do {
            enLigne = .lu(try await service.rendezVous(de: affaire.id, dans: installation))
        } catch {
            enLigne = .echec(EtatRendezVous.indisponibles)
        }
    }

    /// Calendrier : le rendez-vous déjà lu, sinon relu — une lecture qui échoue le DIT ; une
    /// relecture réussie rend aussi ses pages à « Autre agenda… ».
    private func ajouter() async {
        if case .lu(let rendezVous) = enLigne {
            aAjouter = rendezVous
            return
        }
        guard let service = parcours.service.gestesAffaire else {
            avis.dire(EtatRendezVous.indisponibles, ton: .error)
            return
        }
        do {
            let rendezVous = try await service.rendezVous(de: affaire.id, dans: installation)
            enLigne = .lu(rendezVous)
            aAjouter = rendezVous
        } catch {
            avis.dire(ErreurService.depuis(error).phrase, ton: .error)
        }
    }
}

/// Le rendez-vous servi, le temps de sa lecture.
enum EtatRendezVous: Hashable, Sendable {
    case attente
    case lu(RendezVousAffaire)
    case echec(String)

    /// La phrase du site quand le rendez-vous ne se lit pas (`MenuPartage.svelte`).
    static let indisponibles = "Les agendas en ligne ne sont pas disponibles."
}
