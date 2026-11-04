// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La cloche de la barre d'outils : le nombre d'alertes non lues en pastille, un
/// toucher ouvre la liste en feuille. Le site n'a pas de cloche (la page n'a pas
/// d'entrée de menu) ; l'app en fait l'accès, et le nombre se compte sur
/// GET /notifications — aucune route ne le sert seule.
struct ClocheNotifications: ToolbarContent {
    let installation: Installation

    var body: some ToolbarContent {
        let nombre = CompteurNonLues.partage.nombre(installation)
        if #available(iOS 26, *) {
            // La barre d'iOS 26 redessine ses boutons : la pastille est la sienne.
            ToolbarItem(placement: .topBarTrailing) {
                BoutonCloche(installation: installation, point: false).badge(nombre)
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) { BoutonCloche(installation: installation, point: true) }
        }
    }
}

private struct BoutonCloche: View {
    let installation: Installation
    /// Avant iOS 26, le point se dessine sur la cloche.
    let point: Bool
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @State private var ouverte = false

    var body: some View {
        let nombre = CompteurNonLues.partage.nombre(installation)
        Button {
            ouverte = true
        } label: {
            Image(systemName: "bell")
                .symbolEffect(.bounce, options: .nonRepeating, value: mouvementReduit ? 0 : nombre)
                .overlay(alignment: .topTrailing) {
                    if point, nombre > 0 {
                        Circle()
                            .fill(palette.danger)
                            .frame(width: 9, height: 9)
                            .overlay { Circle().strokeBorder(palette.bg, lineWidth: 1.5) }
                            .offset(x: 3, y: -2)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                .animation(.snappy, value: nombre > 0)
        }
        .accessibilityLabel(TextesNotifications.titre)
        .accessibilityValue(nombre > 0 ? TextesNotifications.nonLues(nombre) : "")
        .accessibilityIdentifier("cloche")
        .task(id: installation.hote) {
            await CompteurNonLues.partage.rafraichir(installation, avec: parcours.serviceNotifications)
        }
        .sheet(isPresented: $ouverte) {
            NavigationStack {
                NotificationsView(installation: installation, enFeuille: true)
            }
            .presentationDragIndicator(.visible)
        }
    }
}
