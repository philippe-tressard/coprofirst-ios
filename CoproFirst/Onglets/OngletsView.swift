// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'espace de la résidence ouverte : cinq onglets, seul Affaires est livré.
struct OngletsView: View {
    let installation: Installation
    @State private var onglet = Onglet.affaires

    enum Onglet: Hashable {
        case accueil, affaires, documents, alertes, profil
    }

    var body: some View {
        TabView(selection: $onglet) {
            Bientot(titre: "Accueil").tabItem { Label("Accueil", systemImage: "house") }.tag(Onglet.accueil)
            NavigationStack { AffairesView(installation: installation) }
                .tabItem { Label("Affaires", systemImage: "exclamationmark.bubble") }
                .tag(Onglet.affaires)
            Bientot(titre: "Documents").tabItem { Label("Documents", systemImage: "doc.text") }.tag(Onglet.documents)
            Bientot(titre: "Alertes").tabItem { Label("Alertes", systemImage: "bell") }.tag(Onglet.alertes)
            Bientot(titre: "Profil").tabItem { Label("Profil", systemImage: "person.crop.circle") }.tag(Onglet.profil)
        }
        .tint(Charte.primary)
    }
}

private struct Bientot: View {
    let titre: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Bientôt", systemImage: "hammer",
                description: Text("Cet onglet arrive dans une prochaine version de l'app.")
            )
            .background(Charte.bg)
            .navigationTitle(titre)
        }
    }
}
