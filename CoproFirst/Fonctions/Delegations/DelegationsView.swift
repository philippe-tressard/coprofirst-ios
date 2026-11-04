// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Délégations aidant » (page `delegations` du site, #15) : les délégations que le
/// compte voit, leurs gestes (accepter, révoquer) et, pour le conseil syndical, la
/// création d'une délégation.
///
/// ⚠️ Lecture seule depuis coprofirst#1534 : l'aidant LIT ce que lit la personne aidée.
/// Rien ici ne fait agir quelqu'un au nom d'un autre.
struct DelegationsView: View {
    let contexte: ContexteDeMenu
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var creation = false
    /// Un geste réussi : la liste relue, et un retour haptique.
    @State private var gestes = 0

    init(contexte: ContexteDeMenu) { self.contexte = contexte }

    var body: some View {
        Group {
            if let service = parcours.serviceDelegations {
                page(service)
            } else {
                Bientot(page: contexte.page, installation: contexte.installation)
            }
        }
        .navigationTitle(contexte.page.titre)
        .titreDeMenu()
    }

    private func page(_ service: any ServiceDelegations) -> some View {
        let installation = contexte.installation
        // `$isCS` du site (l'administrateur compris) : lui seul crée une délégation.
        let conseil = DroitsOnglet(profil: parcours.ouverteAJour?.profil).cs
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(TablesDelegations.descriptif)
                    .font(.subheadline)
                    .foregroundStyle(palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Chargement(
                    charger: { try await service.delegations(installation) },
                    contenu: { liste, recharger in
                        ListeDesDelegations(
                            liste: liste, service: service, installation: installation,
                            reussi: {
                                gestes += 1
                                recharger()
                            })
                        .onChange(of: creation) { _, ouverte in if !ouverte { recharger() } }
                    },
                    squelette: { SqueletteDelegations() }
                )
            }
            .padding(.horizontal, Mise.marge)
            .padding(.bottom, 32)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(palette.bg)
        .sensoryFeedback(.success, trigger: gestes)
        .toolbar {
            if conseil {
                ToolbarItem(placement: .primaryAction) {
                    Button { creation = true } label: { Label(TextesDelegations.nouvelle, systemImage: "plus") }
                        .accessibilityIdentifier("delegations.nouvelle")
                }
            }
            PastilleOuSuisJe(installation: installation, cloche: true)
        }
        .sheet(isPresented: $creation) {
            NavigationStack { NouvelleDelegation(service: service, installation: installation) }
        }
    }
}

extension DelegationsView: EcranDeMenu {}

/// Les cartes, et la confirmation de « Révoquer ».
private struct ListeDesDelegations: View {
    let liste: ListeDelegations
    let service: any ServiceDelegations
    let installation: Installation
    let reussi: () -> Void
    @Environment(\.palette) private var palette
    @State private var aRevoquer: Delegation?
    @State private var enCours: Int?
    @State private var erreur: ErreurService?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let erreur { MessageErreur(texte: erreur.phrase).transition(.opacity) }
            if liste.delegations.isEmpty {
                ContentUnavailableView(
                    TextesDelegations.aucune, systemImage: "person.2",
                    description: Text(TablesDelegations.descriptif))
                .accessibilityIdentifier("delegations.vide")
            }
            ForEach(liste.delegations) { delegation in
                CarteDelegation(
                    delegation: delegation, acceptable: delegation.acceptable(par: liste.moi),
                    enCours: enCours == delegation.id,
                    accepter: {
                        Task { await geste(delegation) { try await service.accepterDelegation($0, dans: $1) } }
                    },
                    revoquer: { aRevoquer = delegation })
            }
        }
        .animation(.snappy, value: erreur)
        .confirmationDialog(
            TextesDelegations.revoquerQuestion,
            isPresented: Binding(get: { aRevoquer != nil }, set: { if !$0 { aRevoquer = nil } }),
            titleVisibility: .visible, presenting: aRevoquer
        ) { delegation in
            Button(TextesDelegations.revoquer, role: .destructive) {
                Task { await geste(delegation) { try await service.revoquerDelegation($0, dans: $1) } }
            }
            .accessibilityIdentifier("delegations.revoquer.confirmer")
            Button(TextesDelegations.annuler, role: .cancel) { aRevoquer = nil }
        }
    }

    private func geste(
        _ delegation: Delegation, _ appel: @escaping (Int, Installation) async throws -> Delegation
    ) async {
        aRevoquer = nil
        enCours = delegation.id
        erreur = nil
        do {
            _ = try await appel(delegation.id, installation)
            reussi()
        } catch {
            self.erreur = ErreurService.depuis(error)
        }
        enCours = nil
    }
}

private struct SqueletteDelegations: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                CarteDelegation(
                    delegation: Delegation(
                        id: 0, mandantId: 0, mandantNom: "Une personne aidée", aidantId: 0,
                        aidantNom: "Son proche aidant", statut: "active", motif: "Le motif de la délégation",
                        dateDebut: nil, dateFin: nil),
                    acceptable: false, enCours: false, accepter: {}, revoquer: {})
            }
        }
    }
}
