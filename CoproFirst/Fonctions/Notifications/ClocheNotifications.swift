// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La cloche de la barre d'outils : le nombre d'alertes non lues en pastille, un
/// toucher ouvre la liste en feuille — une seule pour tout l'espace, posée par
/// `OngletsView` sur `parcours.clocheOuverte`, que rouvre aussi une notification touchée
/// (#17). Le site n'a pas de cloche (la page n'a pas
/// d'entrée de menu) ; l'app en fait l'accès, et le nombre se compte sur
/// GET /notifications — aucune route ne le sert seule.
struct ClocheNotifications: ToolbarContent {
    let installation: Installation

    var body: some ToolbarContent {
        if #available(iOS 26, *) {
            // La pastille de la barre d'iOS 26 ne convient pas : elle suit la taille du
            // système et débordait de la barre en très grand texte, et elle n'est relue
            // qu'à la création de l'élément — sur le Fil, le compte arrive après, et elle
            // ne venait jamais ; recréer l'élément dérangeait la navigation (CI, iOS 26.5).
            // Le point de `bell.badge`, de taille fixe, dit qu'une alerte attend ; le
            // nombre est dit par VoiceOver et sous le titre des Notifications.
            ToolbarItem(placement: .topBarTrailing) { BoutonCloche(installation: installation, point: .symbole) }
        } else {
            ToolbarItem(placement: .topBarTrailing) { BoutonCloche(installation: installation, point: .dessine) }
        }
    }
}

private struct BoutonCloche: View {
    let installation: Installation
    /// Comment le bouton montre qu'une alerte attend, quand la pastille de la barre ne le fait pas.
    enum Point {
        /// `bell.badge` : le point fait partie du symbole (iOS 26).
        case symbole
        /// Avant iOS 26 : un point dessiné sur la cloche.
        case dessine
    }

    let point: Point
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit

    var body: some View {
        let nombre = CompteurNonLues.partage.nombre(installation)
        Button {
            parcours.clocheOuverte = true
        } label: {
            Image(systemName: point == .symbole && nombre > 0 ? "bell.badge" : "bell")
                .symbolRenderingMode(point == .symbole && nombre > 0 ? .palette : .monochrome)
                .foregroundStyle(point == .symbole && nombre > 0 ? palette.danger : palette.primary, palette.primary)
                .symbolEffect(.bounce, options: .nonRepeating, value: mouvementReduit ? 0 : nombre)
                .overlay(alignment: .topTrailing) {
                    if point == .dessine, nombre > 0 {
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
        .accessibilityShowsLargeContentViewer()
        .accessibilityLabel(TextesNotifications.titre)
        .accessibilityValue(nombre > 0 ? TextesNotifications.nonLues(nombre) : "")
        .accessibilityIdentifier("cloche")
        .task(id: installation.hote) {
            await CompteurNonLues.partage.rafraichir(installation, avec: parcours.serviceNotifications)
        }
    }
}

extension View {
    /// La feuille des notifications de la résidence ouverte (la cloche, une notification touchée).
    func feuilleNotifications(_ installation: Installation, ouverte: Binding<Bool>) -> some View {
        sheet(isPresented: ouverte) {
            NavigationStack {
                NotificationsView(installation: installation, enFeuille: true)
            }
            .presentationDragIndicator(.visible)
        }
    }
}
