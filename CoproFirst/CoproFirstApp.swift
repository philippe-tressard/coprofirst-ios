// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

@main
struct CoproFirstApp: App {
    @State private var parcours: Parcours
    @State private var reseau = Reseau()

    init() {
        ApparenceNavigation.appliquer()
        _parcours = State(initialValue: Lancement.parcours(ProcessInfo.processInfo.arguments))
    }

    var body: some Scene {
        WindowGroup {
            RacineView()
                .environment(parcours)
                .environment(reseau)
        }
    }
}

/// Les arguments de lancement des tests d'interface et des captures :
/// `-api-simulee` (aucune requête ne part), `-ecran residence|connexion|affaires`.
/// Hors de ces arguments, l'app parle aux vraies installations.
enum Lancement {
    @MainActor
    static func parcours(_ arguments: [String]) -> Parcours {
        guard arguments.contains("-api-simulee") else {
            return Parcours(service: ServiceAPI(), connues: InstallationsConnues())
        }
        let reglages = UserDefaults(suiteName: "fr.coprofirst.app.simulee") ?? .standard
        reglages.removePersistentDomain(forName: "fr.coprofirst.app.simulee")
        let connues = InstallationsConnues(reglages: reglages)
        let residence = ServiceSimule.residence
        let parcours = Parcours(service: ServiceSimule(), connues: connues)
        let ecran = arguments.firstIndex(of: "-ecran").flatMap {
            arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil
        }
        switch ecran {
        case "residence":
            connues.retenir(residence)
            connues.retenir(
                Installation(
                    adresse: URL(string: "https://demo.coprofirst.fr")!, nom: "Résidence Les Glycines",
                    aUnLogo: false))
            parcours.chemin = [.residence]
        case "connexion":
            parcours.chemin = [.residence, .connexion(residence)]
        case "affaires":
            parcours.ouvrir(residence)
        default:
            break
        }
        return parcours
    }
}
