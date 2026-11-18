// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La liste de la cloche (#226) : en tête le nom de la résidence, puis les non lues (urgentes
/// devant), puis « Déjà lues », repliée. Un toucher ouvre le détail ; rien ne se marque
/// comme lu. La liste se relit à chaque retour au premier plan ; l'iPhone proche propose de la
/// continuer (Handoff).
struct ClocheView: View {
    let residence: String
    /// L'adresse de la résidence : « Continuer sur l'iPhone » (Handoff) ouvre sa cloche.
    let adresse: URL?
    @State var lecteur: LecteurCloche
    @State private var luesOuvertes = false
    @Environment(\.scenePhase) private var phase

    var body: some View {
        NavigationStack {
            List {
                contenu
            }
            .navigationTitle(residence)
            .accessibilityIdentifier("montre.cloche")
            .navigationDestination(for: NotificationRecue.self) { AlerteView(alerte: $0) }
        }
        .task { await lecteur.lire() }
        // Handoff : l'iPhone propose d'ouvrir la cloche de CETTE résidence (`ClocheSurLiPhone`).
        .userActivity(ClocheSurLiPhone.type, isActive: adresse != nil) { activite in
            guard let adresse else { return }
            activite.title = residence
            activite.isEligibleForHandoff = true
            activite.addUserInfoEntries(from: ClocheSurLiPhone.userInfo(adresse))
        }
        .onChange(of: phase) { avant, apres in
            // Une relecture au RETOUR au premier plan, pas au lancement : la première lecture
            // vient de partir, la liste ne se reconstruit pas sous le doigt.
            if apres == .active, avant == .background { Task { await lecteur.lire() } }
        }
    }

    @ViewBuilder
    private var contenu: some View {
        switch lecteur.lecture {
        case .enCours:
            ProgressView(TextesMontre.chargement)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("montre.chargement")
        case .injoignable:
            VStack(spacing: MiseMontre.espace) {
                Text(TextesMontre.injoignable).multilineTextAlignment(.center)
                Button(TextesMontre.reessayer) { Task { await lecteur.relire() } }
                    .accessibilityIdentifier("montre.reessayer")
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .accessibilityIdentifier("montre.injoignable")
        case .lue(let cloche):
            alertes(cloche)
        }
    }

    @ViewBuilder
    private func alertes(_ cloche: Cloche) -> some View {
        if cloche.nonLues.isEmpty {
            Text(TextesMontre.aucuneAlerte)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("montre.vide")
        }
        ForEach(cloche.nonLues) { LigneAlerte(alerte: $0) }
        if !cloche.lues.isEmpty {
            Button {
                withAnimation(.snappy) { luesOuvertes.toggle() }
            } label: {
                LabeledContent(TextesMontre.dejaLues) { Text(FormatsDuSite.nombre(cloche.lues.count)) }
            }
            .accessibilityValue(luesOuvertes ? TextesMontre.depliees : TextesMontre.repliees)
            .accessibilityIdentifier("montre.dejaLues")
            if luesOuvertes {
                ForEach(cloche.lues) { LigneAlerte(alerte: $0) }
            }
        }
    }
}
