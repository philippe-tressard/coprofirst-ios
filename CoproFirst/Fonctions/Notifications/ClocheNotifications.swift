// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La cloche de la barre d'outils : le nombre d'alertes non lues en pastille, un
/// toucher ouvre la liste en feuille. Le site n'a pas de cloche (la page n'a pas
/// d'entrée de menu) ; l'app en fait l'accès, et le nombre se compte sur
/// GET /notifications — aucune route ne le sert seule.
struct ClocheNotifications: ToolbarContent {
    let installation: Installation
    @Environment(\.dynamicTypeSize) private var taille

    var body: some ToolbarContent {
        if #available(iOS 26, *), !taille.isAccessibilitySize {
            // La barre d'iOS 26 redessine ses boutons : la pastille est la sienne.
            // La barre ne relit la pastille qu'à la création de l'élément : une identité
            // par nombre la recrée quand il change. Le nombre est figé tant que la liste
            // est ouverte — recréer le bouton refermerait la feuille qu'il présente.
            let nombre = CompteurNonLues.partage.nombreAffiche(installation)
            ToolbarItem(placement: .topBarTrailing) {
                BoutonCloche(installation: installation, point: .pastille).badge(nombre).id(nombre)
            }
        } else if #available(iOS 26, *) {
            // Aux tailles d'accessibilité, la pastille de la barre suit le texte du système
            // et déborde : le point du symbole, de taille fixe, la remplace ; le nombre
            // reste dit par VoiceOver et sous le titre des Notifications.
            ToolbarItem(placement: .topBarTrailing) {
                BoutonCloche(installation: installation, point: .symbole)
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) { BoutonCloche(installation: installation, point: .dessine) }
        }
    }
}

private struct BoutonCloche: View {
    let installation: Installation
    /// Comment le bouton montre qu'une alerte attend, quand la pastille de la barre ne le fait pas.
    enum Point {
        /// La pastille de la barre (iOS 26) suffit.
        case pastille
        /// `bell.badge` : le point fait partie du symbole (iOS 26, tailles d'accessibilité).
        case symbole
        /// Avant iOS 26 : un point dessiné sur la cloche.
        case dessine
    }

    let point: Point
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @State private var ouverte = false

    var body: some View {
        let nombre = CompteurNonLues.partage.nombre(installation)
        Button {
            CompteurNonLues.partage.figer(installation)
            ouverte = true
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
        .sheet(
            isPresented: $ouverte, onDismiss: { CompteurNonLues.partage.liberer(installation) },
            content: {
                NavigationStack {
                    NotificationsView(installation: installation, enFeuille: true)
                }
                .presentationDragIndicator(.visible)
            })
    }
}
