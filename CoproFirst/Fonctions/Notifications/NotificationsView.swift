// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les alertes de l'utilisateur dans la résidence ouverte — la cloche les ouvre en
/// feuille. Sections « Aujourd'hui » et « Plus anciennes », comme le site.
///
/// Les gestes se VOIENT (retour de Philippe, 05/11/2026 : 146 notifications, « pas la
/// possibilité de les supprimer ou de tout marquer comme lu ») : « Tout marquer lu » en
/// haut à gauche dès qu'une alerte attend ; « Supprimer les lues » en tête de la liste
/// dès qu'il y en a une (10/11/2026 : « il faut supprimer les lues », #53) ; « Modifier »
/// en haut à droite, qui permet de choisir plusieurs alertes et de les supprimer. Le
/// balayage reste un raccourci, et un toucher marque lu.
struct NotificationsView: View {
    let installation: Installation
    /// Ouverte par la cloche : un bouton « OK » la referme.
    var enFeuille = false
    @Environment(Parcours.self) private var parcours
    @Environment(NotificationsPush.self) private var push
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var fermer
    @State private var etat = EtatNotifications()
    @State private var aConfirmer: SuppressionDemandee?
    @State private var modeEdition = EditMode.inactive
    @State private var selection: Set<Int> = []
    @State private var supprimees = 0
    @State private var avis = AvisDuGeste()

    private var enEdition: Bool { modeEdition.isEditing }

    var body: some View {
        List(selection: $selection) {
            if etat.phase == .chargement {
                Section { ForEach(0..<4, id: \.self) { _ in LigneNotification(notification: Self.squelette) } }
                    .redacted(reason: .placeholder)
            } else {
                if !enEdition { OffrePush() }
                if let echec = etat.echec {
                    MessageErreur(texte: echec.phrase).listRowBackground(Color.clear).listRowInsets(.init())
                }
                if etat.lues > 0 { gesteSurLesLues }
                let sections = etat.sections()
                section(TextesNotifications.aujourdhui, sections.aujourdhui)
                section(TextesNotifications.anciennes, sections.anciennes)
            }
        }
        .environment(\.editMode, $modeEdition)
        .scrollContentBackground(.hidden)
        .background(palette.bg)
        .overlay { etatVide }
        .navigationTitle(TextesNotifications.titre)
        .titreDeMenu()
        .modifier(SousTitreNonLues(nombre: etat.nonLues))
        .toolbar { barre }
        .avisEphemere(avis)
        .safeAreaInset(edge: .bottom, spacing: 0) { if enEdition { barreDeSuppression } }
        .animation(.snappy, value: enEdition)
        .animation(.snappy, value: push.offreDue)
        .refreshable { await etat.charger(installation, avec: parcours.serviceNotifications) }
        .task { await etat.charger(installation, avec: parcours.serviceNotifications) }
        .onChange(of: etat.liste.isEmpty) { _, vide in if vide { modeEdition = .inactive } }
        .sensoryFeedback(.success, trigger: etat.nonLues == 0 && etat.phase == .pret)
        .sensoryFeedback(.success, trigger: supprimees)
        .sensoryFeedback(.selection, trigger: selection)
        // UNE confirmation pour les trois suppressions (une, la sélection, les lues) :
        // la demande dit ce qui part. Posée sur la liste, jamais sur une rangée.
        .confirmationDialog(
            TextesNotifications.confirmerTitre, isPresented: confirmationPresentee, titleVisibility: .visible,
            presenting: aConfirmer
        ) { demande in
            Button(demande.libelle, role: .destructive) {
                Task { await supprimer(demande) }
            }
            .accessibilityIdentifier("notifications.confirmerSuppression")
        } message: { demande in
            Text(demande.message)
        }
    }

    @ViewBuilder
    private func section(_ titre: String, _ notifications: [NotificationRecue]) -> some View {
        if !notifications.isEmpty {
            Section {
                ForEach(notifications) { notification in
                    ligne(notification)
                        .listRowBackground(palette.surface)
                        .swipeActions(edge: .leading) {
                            if !notification.lue {
                                Button {
                                    Task { await marquerLue(notification) }
                                } label: {
                                    Label(TextesNotifications.marquerLu, systemImage: "envelope.open")
                                }
                                .tint(palette.primaryPlein)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                aConfirmer = .une(notification)
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

    /// Hors édition, un toucher marque lu ; en édition, il choisit (la liste s'en charge).
    @ViewBuilder
    private func ligne(_ notification: NotificationRecue) -> some View {
        if enEdition {
            LigneNotification(notification: notification)
        } else {
            Button {
                Task { await marquerLue(notification) }
            } label: {
                LigneNotification(notification: notification)
            }
            .buttonStyle(.plain)
        }
    }

    @ToolbarContentBuilder
    private var barre: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if enEdition {
                let toutes = !etat.liste.isEmpty && selection.count == etat.liste.count
                Button(toutes ? TextesNotifications.toutDeselectionner : TextesNotifications.toutSelectionner) {
                    selection = toutes ? [] : Set(etat.liste.map(\.id))
                }
                .accessibilityIdentifier("notifications.toutSelectionner")
            } else if etat.nonLues > 0 {
                Button(TextesNotifications.toutMarquerLu) {
                    Task { await etat.toutMarquerLu(installation, avec: parcours.serviceNotifications) }
                }
                .fontWeight(.semibold)
                .accessibilityHint(TextesNotifications.nonLues(etat.nonLues))
                .accessibilityIdentifier("notifications.toutMarquerLu")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if !etat.liste.isEmpty {
                Button(enEdition ? TextesNotifications.terminer : TextesNotifications.modifier) {
                    withAnimation(.snappy) {
                        modeEdition = enEdition ? .inactive : .active
                        selection = []
                    }
                }
                .fontWeight(enEdition ? .semibold : .regular)
                .accessibilityIdentifier("notifications.modifier")
            }
        }
        if enFeuille, !enEdition {
            ToolbarItem(placement: .confirmationAction) {
                Button("OK") { fermer() }.accessibilityIdentifier("notifications.ok")
            }
        }
    }

    /// « Supprimer les lues », le geste direct du site (l'en-tête de sa page) : toutes les
    /// lues du compte, après confirmation. En tête de la liste et non dans une barre : il
    /// défile avec elle, grandit donc avec le texte sans rien lui prendre, et un geste
    /// définitif ne se pose pas sous le pouce, à côté de « Modifier ». Absent sans
    /// notification lue, comme sur le site ; pendant une sélection, il attend. Discret
    /// comme le bouton du site (`btn-outline`, pas un aplat rouge) : la surface d'une
    /// carte, le rouge dans le texte — et dans la confirmation.
    private var gesteSurLesLues: some View {
        Button {
            aConfirmer = .lues(etat.lues)
        } label: {
            // Pas un `Label` : en très grand texte, sa seconde ligne repartait sous l'icône.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "trash").accessibilityHidden(true)
                Text(TextesNotifications.supprimerLues).multilineTextAlignment(.leading)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.danger)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: Mise.cible)
            .background(palette.surface, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
        }
        .buttonStyle(StyleCarte())
        .disabled(enEdition)
        .opacity(enEdition ? 0.45 : 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowBackground(Color.clear)
        .listRowInsets(.init())
        .listRowSeparator(.hidden)
        .accessibilityIdentifier("notifications.supprimerLues")
    }

    /// En édition : supprimer la sélection. Posée au bas du contenu (au-dessus de la barre
    /// d'onglets), jamais dans une barre d'outils du bas que la barre d'onglets cacherait.
    private var barreDeSuppression: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 8)
            Button(role: .destructive) {
                aConfirmer = .selection(selection)
            } label: {
                Label(TextesNotifications.supprimerSelection(selection.count), systemImage: "trash")
                    .fontWeight(.semibold)
                    .contentTransition(.numericText())
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.dangerPlein)
            .disabled(selection.isEmpty)
            .accessibilityShowsLargeContentViewer()
            .accessibilityIdentifier("notifications.supprimerSelection")
        }
        .font(.subheadline)
        // Une barre ne grandit pas sans fin : elle mangerait la liste (très grand texte).
        // Au-delà, la loupe d'accessibilité montre le libellé (appui long).
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.horizontal, Mise.marge)
        .padding(.vertical, 10)
        .frame(minHeight: Mise.cible)
        .background(.bar)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func marquerLue(_ notification: NotificationRecue) async {
        await etat.marquerLue(notification, dans: installation, avec: parcours.serviceNotifications)
    }

    /// La demande confirmée part par SA route ; les lues parties, la phrase du site le dit.
    private func supprimer(_ demande: SuppressionDemandee) async {
        let service = parcours.serviceNotifications
        switch demande {
        case .une(let notification):
            await etat.supprimer(notification, dans: installation, avec: service)
        case .selection(let choisies):
            selection = []
            if await etat.supprimer(choisies, dans: installation, avec: service) { supprimees += 1 }
        case .lues:
            if await etat.supprimerLues(installation, avec: service) { avis.dire(TextesNotifications.luesSupprimees) }
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

    private var confirmationPresentee: Binding<Bool> {
        Binding(get: { aConfirmer != nil }, set: { if !$0 { aConfirmer = nil } })
    }

    private static let squelette = NotificationRecue(
        id: 0, type: "", titre: "Une alerte de la résidence", corps: "Son texte se charge, sur deux lignes.",
        lue: true, urgente: false, creeLe: .now)
}

/// Le nombre de non lues sous le titre (iOS 26, `navigationSubtitle`) ; avant, le
/// bouton « Tout marquer lu » le porte dans son indice VoiceOver.
private struct SousTitreNonLues: ViewModifier {
    let nombre: Int

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.navigationSubtitle(nombre > 0 ? TextesNotifications.nonLues(nombre) : "")
        } else {
            content
        }
    }
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
