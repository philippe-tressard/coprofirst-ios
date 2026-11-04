// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'onglet « Annonces Hall » de l'Espace CS (`OngletAnnoncesHall.svelte`, #15) : la
/// création d'une affiche, et les archives des affiches déjà produites, avec leurs gestes.
struct OngletAnnoncesHall: View {
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var vue = Vue.nouvelle
    /// Le compte rendu de la dernière création, montré en tête des archives.
    @State private var creee: String?

    enum Vue: Hashable { case nouvelle, archives }

    var body: some View {
        if let service = parcours.serviceAnnoncesHall {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    choix(TextesAnnoncesHall.nouvelle, .nouvelle, "annonces-hall.vue.nouvelle")
                    choix(TextesAnnoncesHall.archives, .archives, "annonces-hall.vue.archives")
                }
                .sensoryFeedback(.selection, trigger: vue)
                switch vue {
                case .nouvelle:
                    NouvelleAnnonceHall(service: service, installation: installation) { annonce in
                        creee = TextesAnnoncesHall.creee(annonce)
                        withAnimation(.snappy) { vue = .archives }
                    }
                case .archives:
                    ArchivesAnnoncesHall(service: service, installation: installation, creee: $creee)
                }
                Text(TextesAnnoncesHall.surLeSite).font(.footnote).foregroundStyle(palette.textMuted)
            }
        } else {
            MessageErreur(texte: ErreurService.inattendue(501).phrase)
        }
    }

    private func choix(_ libelle: String, _ cible: Vue, _ identifiant: String) -> some View {
        Pastille(libelle: libelle, retenue: vue == cible) { withAnimation(.snappy) { vue = cible } }
            .accessibilityIdentifier(identifiant)
    }
}

/// Les affiches en cours puis les archivées, chacune dépliable, et leurs gestes.
private struct ArchivesAnnoncesHall: View {
    let service: any ServiceAnnoncesHall
    let installation: Installation
    @Binding var creee: String?
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var aSupprimer: AnnonceHall?
    @State private var erreur: ErreurService?
    @State private var gestes = 0

    var body: some View {
        let service = service
        let installation = installation
        let administrateur = DroitsOnglet(profil: parcours.ouverteAJour?.profil).administrateur
        Chargement(
            charger: {
                async let actives = service.annoncesHall(archivees: false, dans: installation)
                async let archivees = service.annoncesHall(archivees: true, dans: installation)
                return try await actives + archivees
            },
            contenu: { annonces, recharger in
                VStack(alignment: .leading, spacing: 12) {
                    if let creee {
                        Label(creee, systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.successTexte)
                            .accessibilityIdentifier("annonces-hall.creee")
                    }
                    if let erreur { MessageErreur(texte: erreur.phrase) }
                    if annonces.isEmpty {
                        ContentUnavailableView(
                            TextesAnnoncesHall.aucune, systemImage: "doc.richtext",
                            description: Text(TextesAnnoncesHall.aucuneDetail))
                        .accessibilityIdentifier("annonces-hall.vide")
                    }
                    ForEach(annonces) { annonce in
                        CarteAnnonceHall(
                            annonce: annonce, administrateur: administrateur,
                            geste: { geste in Task { await faire(geste, annonce, recharger) } })
                    }
                }
                .animation(.snappy, value: annonces)
                .confirmationDialog(
                    aSupprimer.map(TextesAnnoncesHall.supprimerQuestion) ?? "",
                    isPresented: Binding(get: { aSupprimer != nil }, set: { if !$0 { aSupprimer = nil } }),
                    titleVisibility: .visible, presenting: aSupprimer
                ) { annonce in
                    Button(TextesAnnoncesHall.supprimer, role: .destructive) {
                        Task { await faire(.supprimer, annonce, recharger, confirme: true) }
                    }
                    .accessibilityIdentifier("annonces-hall.supprimer.confirmer")
                } message: { annonce in
                    Text(TextesAnnoncesHall.supprimerMessage(annonce))
                }
            },
            squelette: { SqueletteAnnoncesHall() }
        )
        .sensoryFeedback(.success, trigger: gestes)
    }

    private func faire(
        _ geste: GesteAnnonceHall, _ annonce: AnnonceHall, _ recharger: () -> Void, confirme: Bool = false
    ) async {
        if geste == .supprimer && !confirme {
            aSupprimer = annonce
            return
        }
        aSupprimer = nil
        erreur = nil
        creee = nil
        do {
            switch geste {
            case .renvoyer: try await service.renvoyerAnnonceHall(annonce.id, dans: installation)
            case .archiver:
                try await service.archiverAnnonceHall(annonce.id, archivee: !annonce.archivee, dans: installation)
            case .supprimer: try await service.supprimerAnnonceHall(annonce.id, dans: installation)
            }
            gestes += 1
            recharger()
        } catch {
            withAnimation(.snappy) { self.erreur = ErreurService.depuis(error) }
        }
    }
}

private struct SqueletteAnnoncesHall: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                Carte {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Une annonce de hall").font(.headline)
                        Text("L'aperçu de l'annonce arrive, sur deux lignes au plus.").font(.subheadline)
                    }
                }
            }
        }
    }
}
