// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import WidgetKit

/// Après une lecture de l'app, le widget dit la même chose : le résumé s'écrit dans l'App
/// Group, puis WidgetKit relit ses chronologies — seulement s'il a changé (#226).
@MainActor
final class Surfaces {
    private let ecrire: (ResumeCloche) -> Bool
    private let recharger: () -> Void
    private var dernier: ResumeCloche?

    init(
        ecrire: @escaping (ResumeCloche) -> Bool = { PartageDuResume.ecrire($0) },
        recharger: @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }
    ) {
        self.ecrire = ecrire
        self.recharger = recharger
    }

    func publier(_ resume: ResumeCloche) {
        guard resume != dernier else { return }
        guard ecrire(resume) else { return }
        dernier = resume
        recharger()
    }
}
