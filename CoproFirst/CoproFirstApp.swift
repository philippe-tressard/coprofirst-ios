// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

@main
struct CoproFirstApp: App {
    @State private var parcours: Parcours
    @State private var reseau = Reseau()

    init() {
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
/// `-api-simulee` (aucune requête ne part) et
/// `-ecran en-savoir-plus|connexion|faceid|demo|fil|affaires`, et avec `fil`,
/// `-ouvrir <type:id>` pour ouvrir d'emblée un élément du fil.
/// Hors de ces arguments, l'app parle aux vraies installations.
enum Lancement {
    @MainActor
    static func parcours(_ arguments: [String]) -> Parcours {
        guard arguments.contains("-api-simulee") else {
            return Parcours(service: ServiceAPI(), connues: InstallationsConnues())
        }
        let suite = "fr.coprofirst.app.simulee"
        let reglages = UserDefaults(suiteName: suite) ?? .standard
        reglages.removePersistentDomain(forName: suite)
        let parcours = Parcours(service: ServiceSimule(), connues: InstallationsConnues(reglages: reglages))
        let residence = ServiceSimule.residence
        let ecran = arguments.firstIndex(of: "-ecran").flatMap {
            arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil
        }
        switch ecran {
        case "en-savoir-plus":
            parcours.chemin = [.enSavoirPlus]
        case "connexion":
            parcours.reconnue = residence
            parcours.chemin = [.connexion(.init(installation: residence))]
        case "faceid":
            parcours.ouvrir(residence, premiereConnexion: true)
        case "demo":
            parcours.chemin = [.demo]
        case "fil":
            parcours.connues.noterFaceIDProposee(residence)
            parcours.ouvrir(residence)
            parcours.aOuvrir = arguments.firstIndex(of: "-ouvrir").flatMap {
                arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil
            }
        case "affaires":
            parcours.connues.noterFaceIDProposee(residence)
            parcours.ouvrir(residence)
        default:
            break
        }
        return parcours
    }
}
