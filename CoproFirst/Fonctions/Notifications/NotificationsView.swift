// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les alertes de l'utilisateur dans la résidence ouverte — la cloche les ouvre en
/// feuille. Sections « Aujourd'hui » et « Plus anciennes », comme le site ; un toucher
/// marque lu, un balayage marque lu ou supprime (après confirmation : c'est définitif).
struct NotificationsView: View {
    let installation: Installation
    /// Ouverte par la cloche : un bouton « OK » la referme.
    var enFeuille = false
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var fermer
    @State private var etat = EtatNotifications()
    @State private var aSupprimer: NotificationRecue?

    var body: some View {
        List {
            if etat.phase == .chargement {
                Section { ForEach(0..<4, id: \.self) { _ in LigneNotification(notification: Self.squelette) } }
                    .redacted(reason: .placeholder)
            } else {
                if let echec = etat.echec {
                    MessageErreur(texte: echec.phrase).listRowBackground(Color.clear).listRowInsets(.init())
                }
                let sections = etat.sections()
                section(TextesNotifications.aujourdhui, sections.aujourdhui)
                section(TextesNotifications.anciennes, sections.anciennes)
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.bg)
        .overlay { etatVide }
        .navigationTitle(TextesNotifications.titre)
        .titreDeMenu()
        .toolbar { barre }
        .refreshable { await etat.charger(installation, avec: parcours.serviceNotifications) }
        .task { await etat.charger(installation, avec: parcours.serviceNotifications) }
        .sensoryFeedback(.success, trigger: etat.nonLues == 0 && etat.phase == .pret)
        .confirmationDialog(
            TextesNotifications.confirmerTitre, isPresented: aSupprimerPresente, titleVisibility: .visible,
            presenting: aSupprimer
        ) { notification in
            Button(TextesNotifications.supprimer, role: .destructive) {
                Task { await etat.supprimer(notification, dans: installation, avec: parcours.serviceNotifications) }
            }
        } message: { _ in
            Text(TextesNotifications.confirmerMessage)
        }
    }

    @ViewBuilder
    private func section(_ titre: String, _ notifications: [NotificationRecue]) -> some View {
        if !notifications.isEmpty {
            Section {
                ForEach(notifications) { notification in
                    Button {
                        Task {
                            await etat.marquerLue(notification, dans: installation, avec: parcours.serviceNotifications)
                        }
                    } label: {
                        LigneNotification(notification: notification)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(palette.surface)
                    .swipeActions(edge: .leading) {
                        if !notification.lue {
                            Button {
                                Task {
                                    await etat.marquerLue(
                                        notification, dans: installation, avec: parcours.serviceNotifications)
                                }
                            } label: {
                                Label(TextesNotifications.marquerLu, systemImage: "envelope.open")
                            }
                            .tint(palette.primaryPlein)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            aSupprimer = notification
                        } label: {
                            Label(TextesNotifications.supprimer, systemImage: "trash")
                        }
                    }
                    .accessibilityIdentifier("notification.\(notification.id)")
                }
            } header: {
                Text(titre).styleLibelle()
            }
        }
    }

    @ToolbarContentBuilder
    private var barre: some ToolbarContent {
        if enFeuille {
            ToolbarItem(placement: .confirmationAction) {
                Button("OK") { fermer() }.accessibilityIdentifier("notifications.ok")
            }
        }
        ToolbarItem(placement: .bottomBar) {
            if etat.nonLues > 0 {
                HStack {
                    Text(TextesNotifications.nonLues(etat.nonLues))
                        .font(.subheadline)
                        .foregroundStyle(palette.textMuted)
                        .contentTransition(.numericText())
                    Spacer()
                    Button(TextesNotifications.toutMarquerLu) {
                        Task { await etat.toutMarquerLu(installation, avec: parcours.serviceNotifications) }
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("notifications.toutMarquerLu")
                }
            }
        }
    }

    @ViewBuilder
    private var etatVide: some View {
        if case .erreur(let erreur) = etat.phase {
            MessageErreur(texte: erreur.phrase) {
                Task { await etat.charger(installation, avec: parcours.serviceNotifications) }
            }
            .padding(Mise.marge)
        } else if etat.phase == .pret, etat.liste.isEmpty {
            ContentUnavailableView(
                TextesNotifications.vide, systemImage: "bell.slash",
                description: Text(TextesNotifications.videDetail))
        }
    }

    private var aSupprimerPresente: Binding<Bool> {
        Binding(get: { aSupprimer != nil }, set: { if !$0 { aSupprimer = nil } })
    }

    private static let squelette = NotificationRecue(
        id: 0, type: "", titre: "Une alerte de la résidence", corps: "Son texte se charge, sur deux lignes.",
        lue: true, urgente: false, creeLe: .now)
}

/// Une alerte : le point des non lues, le titre, « Urgent », le texte et l'heure.
private struct LigneNotification: View {
    let notification: NotificationRecue
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Circle()
                .fill(notification.lue ? Color.clear : palette.primary)
                .frame(width: 9, height: 9)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) { titre; Spacer(minLength: 4); date }
                    VStack(alignment: .leading, spacing: 4) { titre; date }
                }
                Text(TexteDuSite.riche(notification.corps))
                    .font(.subheadline)
                    .foregroundStyle(palette.textMuted)
                    .tint(palette.primary)
            }
        }
        .padding(.vertical, 6)
        .opacity(notification.lue ? 0.7 : 1)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityValue(notification.lue ? "" : "Non lue")
        .accessibilityHint(notification.lue ? "" : TextesNotifications.marquerLu)
    }

    private var titre: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(notification.titre)
                .font(.body.weight(notification.lue ? .regular : .semibold))
                .foregroundStyle(palette.text)
            if notification.urgente {
                Text(TextesNotifications.urgent)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .foregroundStyle(palette.danger)
                    .background(palette.dangerFond, in: .capsule)
            }
        }
    }

    /// Dans les 24 heures, l'heure seule ; au-delà, la date courte — comme le site.
    private var date: some View {
        let recente = notification.creeLe > Date.now.addingTimeInterval(-24 * 3600)
        return Text(
            recente
                ? FormatsDuSite.heure(notification.creeLe)
                : FormatsDuSite.dateCourte(notification.creeLe)
        )
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(palette.textMuted)
    }
}

extension NotificationsView: EcranDeMenu {
    init(contexte: ContexteDeMenu) {
        self.init(installation: contexte.installation)
    }
}
