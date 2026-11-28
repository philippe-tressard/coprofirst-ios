// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'app Apple TV : l'écran de hall d'une résidence (#218), et rien d'autre. Elle ne fait
/// que lire — aucune saisie après l'adresse, aucun compte de personne : appairée par le
/// conseil syndical (#295), elle fait défiler les annonces de hall de son périmètre.
///
/// Elle compile les MÊMES fichiers que l'app iPhone pour la charte et les formats du site
/// (`project.yml`, cible `CoproFirstTV`) : jamais une copie.
@main
struct CoproFirstTVApp: App {
    @State private var hall = Self.lancement()

    var body: some Scene {
        WindowGroup {
            EcranDeHallView(hall: hall)
                .preferredColorScheme(Self.themeImpose)
                .environment(\.reglagesDuHall, Self.reglages)
        }
    }

    /// Le Trousseau et les vraies installations ; en Debug seulement, l'écran simulé des
    /// captures (`-api-simulee`, `LancementTVSimule`).
    private static func lancement() -> HallTV {
        #if DEBUG
        if let simule = LancementTVSimule.hall(ProcessInfo.processInfo.arguments) { return simule }
        #endif
        return HallTV(memoire: MemoireEcran(coffre: CoffreTrousseau()))
    }

    /// Rien en Release ; en Debug, ce que les captures imposent au Fil (`LancementTVSimule`).
    private static var reglages: ReglagesDuHall {
        #if DEBUG
        LancementTVSimule.reglages(ProcessInfo.processInfo.arguments)
        #else
        ReglagesDuHall()
        #endif
    }

    /// Le thème du système ; en Debug, `-theme clair|sombre` l'impose aux captures : le
    /// simulateur Apple TV ne se règle pas par `simctl ui appearance`.
    private static var themeImpose: ColorScheme? {
        #if DEBUG
        LancementTVSimule.theme(ProcessInfo.processInfo.arguments)
        #else
        nil
        #endif
    }
}
