// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'espace de la résidence ouverte. Ses pages suivent l'ORDRE RÉGLÉ PAR
/// L'ADMINISTRATION (`pages_order`) ; une page réservée à un rôle n'y paraît qu'à qui l'a
/// (`PagesOuvertes`, profil de GET /auth/me).
///
/// LE point de choix de la présentation (#221) : la barre du bas en classe compacte, la
/// barre latérale en classe régulière, le carnet de l'iPhone pliable ouvert (#119) —
/// `Parcours.presentation`, que `RacineView` tient de la classe de taille horizontale et
/// de la posture. Une présentation de plus s'ajoute ICI, sur le même état.
struct OngletsView: View {
    let installation: Installation
    @Environment(\.palette) private var palette
    @Environment(Parcours.self) private var parcours
    @Environment(\.scenePhase) private var phase

    var body: some View {
        let pages = parcours.pagesDeLaBarre(installation)
        @Bindable var parcours = parcours
        Group {
            switch parcours.presentation {
            case .barreDuBas: BarreDuBas(pages: pages, installation: installation)
            case .barreLaterale: BarreLaterale(pages: pages, installation: installation)
            case .carnet: Carnet(pages: pages, installation: installation)
            }
        }
        .tint(palette.primary)
        // L'affaire d'un lien ou d'une notification, quand son onglet n'est pas dans la barre.
        .sheet(item: $parcours.porte.affaireEnFeuille) { affaire in
            NavigationStack {
                DetailAffaireView(id: affaire.id, installation: installation)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fermer") { parcours.porte.affaireEnFeuille = nil }
                                .accessibilityIdentifier("porte.fermer")
                        }
                    }
            }
            .presentationDragIndicator(.visible)
        }
        .feuilleNotifications(installation, ouverte: $parcours.clocheOuverte)
        // La barre dépend des rôles : ils se relisent à l'ouverture de la résidence.
        .task { await parcours.rafraichirProfil() }
        // Les pages vues partent au passage en arrière-plan, comme au `visibilitychange` du site.
        .onChange(of: phase) { _, phase in
            if phase == .background { parcours.audience.viderEnArrierePlan() }
        }
    }
}
