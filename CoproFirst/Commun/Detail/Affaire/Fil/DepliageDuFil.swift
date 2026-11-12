// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Observation
import SwiftUI
import UIKit

/// Ce qui est ouvert dans le fil d'une affaire (#178) : les sections pliées, l'élément
/// ouvert le temps d'un regard, et ceux qu'on garde ouverts.
///
/// - **Un toucher** ouvre un élément quelques secondes (`duree`), puis il se replie seul ;
///   un autre toucher le replie tout de suite. Un seul à la fois.
/// - **Garder ouvert** (double toucher, appui long, ou action d'accessibilité) le laisse
///   ouvert jusqu'à ce qu'on le relâche.
///
/// Chaque changement part dans une animation commune (`mouvement`) : tout l'écran suit,
/// messages compris, et le repli de la minuterie s'anime comme un toucher.
///
/// Un état qui change SEUL (la minuterie) : un objet observable, lu là où il s'affiche —
/// jamais une `Binding` fabriquée par l'écran (la règle d'`AvisEphemere`, #48).
@MainActor @Observable
final class DepliageDuFil {
    /// La durée d'un regard : 4 s, arrêtées avec l'utilisateur le 12/11/2026.
    static let regard: Duration = .seconds(4)

    private(set) var ouvertUnInstant: String?
    private(set) var gardes: Set<String> = []
    private(set) var plies: Set<EtapeFil.Cle>
    @ObservationIgnored let duree: Duration
    @ObservationIgnored private var minuterie: Task<Void, Never>?

    /// Les comptes rendus partent pliés : la suite se lit d'abord (maquette A).
    init(duree: Duration = DepliageDuFil.regard, plies: Set<EtapeFil.Cle> = [.comptesRendus]) {
        self.duree = duree
        self.plies = plies
    }

    /// Aucun mouvement quand « Réduire les animations » est demandé.
    private static var mouvement: Animation? { UIAccessibility.isReduceMotionEnabled ? nil : .snappy }

    private func animer(_ changement: () -> Void) { withAnimation(Self.mouvement, changement) }

    func estOuvert(_ id: String) -> Bool { gardes.contains(id) || ouvertUnInstant == id }
    func estGarde(_ id: String) -> Bool { gardes.contains(id) }
    func estPliee(_ etape: EtapeFil.Cle) -> Bool { plies.contains(etape) }

    /// Un toucher : l'élément s'ouvre un instant, ou se replie s'il l'était déjà. Un
    /// élément gardé ouvert ne bouge pas : on le relâche par le même geste qui l'a gardé.
    func toucher(_ id: String) {
        guard !gardes.contains(id) else { return }
        minuterie?.cancel()
        guard ouvertUnInstant != id else {
            animer { ouvertUnInstant = nil }
            return
        }
        animer { ouvertUnInstant = id }
        minuterie = Task { [duree, weak self] in
            try? await Task.sleep(for: duree)
            guard !Task.isCancelled, let self, ouvertUnInstant == id else { return }
            animer { ouvertUnInstant = nil }
        }
    }

    /// Garder ouvert, ou relâcher.
    func basculerGarde(_ id: String) {
        if ouvertUnInstant == id { minuterie?.cancel() }
        animer {
            if ouvertUnInstant == id { ouvertUnInstant = nil }
            if gardes.remove(id) == nil { gardes.insert(id) }
        }
    }

    func basculerPli(_ etape: EtapeFil.Cle) {
        animer { if plies.remove(etape) == nil { plies.insert(etape) } }
    }
}
