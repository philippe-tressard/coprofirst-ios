// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// UN geste qui a besoin du serveur (répondre, voter, déposer, exporter, modifier…) :
/// en consultation hors ligne (#101), il garde sa place, grisé, et VoiceOver dit pourquoi.
///
/// LE point de la règle : un contrôle se déclare `.gesteEnLigne()`, il n'écrit jamais
/// `if horsLigne`. Les droits affichés datent peut-être : on n'offre pas un geste que le
/// serveur pourrait refuser. Le verrou, lui, n'est pas ici : en consultation, la porte du
/// client (`GarderLesLectures`) refuse toute écriture avant qu'elle parte — un geste non
/// déclaré échoue donc avec la phrase « Vous êtes hors ligne… », il ne part jamais.
private struct GesteEnLigne: ViewModifier {
    @Environment(Parcours.self) private var parcours: Parcours?

    func body(content: Content) -> some View {
        if parcours?.consultation != nil {
            content
                .disabled(true)
                .accessibilityHint(TextesHorsLigne.raison)
        } else {
            content
        }
    }
}

extension View {
    /// Ce contrôle agit sur le serveur : désactivé, en place, tant que la résidence est
    /// consultée hors ligne.
    func gesteEnLigne() -> some View { modifier(GesteEnLigne()) }
}

/// Reprend la session dès que le réseau revient — ou que l'app revient au premier plan —
/// pendant une consultation hors ligne. Posé une fois, sur l'espace de la résidence.
private struct RepriseEnLigne: ViewModifier {
    @Environment(Parcours.self) private var parcours
    @Environment(Reseau.self) private var reseau
    @Environment(\.scenePhase) private var phase

    private struct Declencheur: Equatable {
        let consultation: Bool
        let enLigne: Bool
        let active: Bool
    }

    func body(content: Content) -> some View {
        let declencheur = Declencheur(
            consultation: parcours.consultation != nil, enLigne: reseau.enLigne, active: phase == .active)
        content.task(id: declencheur) {
            guard declencheur.consultation, declencheur.enLigne, declencheur.active else { return }
            await parcours.reprendreEnLigne()
        }
    }
}

extension View {
    func repriseEnLigne() -> some View { modifier(RepriseEnLigne()) }
}
