// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les deux gestes de sortie, confirmés par une feuille d'action iOS. Une seule
/// fonction derrière chacun (`Parcours.deconnecter`, `Parcours.oublierTout`).
enum GesteDeSortie: Identifiable {
    case deconnecter(Installation)
    case oublierTout

    var id: String {
        switch self {
        case .deconnecter(let installation): "deconnecter-\(installation.hote)"
        case .oublierTout: "oublier-tout"
        }
    }

    var titre: String {
        switch self {
        case .deconnecter(let installation): "Se déconnecter de \(installation.nom) ?"
        case .oublierTout: "Oublier toutes les résidences ?"
        }
    }

    var message: String {
        switch self {
        case .deconnecter:
            "Vous reviendrez à l'écran de connexion. Face ID vous sera de nouveau proposé."
        case .oublierTout:
            "Chaque session sera fermée et l'app reviendra à son accueil, comme neuve."
        }
    }

    var bouton: String {
        switch self {
        case .deconnecter: "Se déconnecter"
        case .oublierTout: "Oublier toutes les résidences"
        }
    }
}

extension View {
    /// La feuille d'action qui confirme un geste de sortie, puis l'exécute.
    func confirmationDeSortie(_ geste: Binding<GesteDeSortie?>, parcours: Parcours) -> some View {
        confirmationDialog(
            geste.wrappedValue?.titre ?? "",
            isPresented: Binding(
                get: { geste.wrappedValue != nil }, set: { if !$0 { geste.wrappedValue = nil } }),
            titleVisibility: .visible, presenting: geste.wrappedValue
        ) { choisi in
            Button(choisi.bouton, role: .destructive) {
                Task {
                    switch choisi {
                    case .deconnecter(let installation): await parcours.deconnecter(installation)
                    case .oublierTout: await parcours.oublierTout()
                    }
                }
            }
            .accessibilityIdentifier("sortie.confirmer")
            Button("Annuler", role: .cancel) {}
        } message: { choisi in
            Text(choisi.message)
        }
    }
}
