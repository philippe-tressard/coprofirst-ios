// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

@main
struct CoproFirstApp: App {
    @UIApplicationDelegateAdaptor(DelegueApp.self) private var delegue
    @State private var parcours: Parcours
    @State private var reseau = Reseau()
    @State private var vitrine: Vitrine

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        _parcours = State(initialValue: Lancement.parcours(arguments))
        _vitrine = State(initialValue: Lancement.vitrine(arguments))
    }

    var body: some Scene {
        WindowGroup {
            RacineView()
                .environment(parcours)
                .environment(reseau)
                .environment(vitrine)
                .environment(delegue.push)
                .task {
                    await delegue.push.attacher(parcours)
                    #if DEBUG
                    LancementSimule.toucherNotification(ProcessInfo.processInfo.arguments, delegue.push)
                    #endif
                }
        }
    }
}

/// Le lancement : l'app parle aux vraies installations, et lit coprofirst.fr. En Debug
/// seul, les tests d'interface et les captures lancent l'API simulée (`LancementSimule`,
/// #84) — un build Release ne la compile pas.
enum Lancement {
    @MainActor
    static func vitrine(_ arguments: [String]) -> Vitrine {
        #if DEBUG
        if let vitrine = LancementSimule.vitrine(arguments) { return vitrine }
        #endif
        return .enLigne()
    }

    @MainActor
    static func parcours(_ arguments: [String]) -> Parcours {
        #if DEBUG
        if let parcours = LancementSimule.parcours(arguments) { return parcours }
        #endif
        return Parcours(service: ServiceAPI(), connues: InstallationsConnues())
    }
}
