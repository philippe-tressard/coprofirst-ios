// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// Des alertes inventées, pour les aperçus, les tests et les captures : aucune
/// personne, aucune requête. Leur état (lue, supprimée) vit le temps du service.
extension ServiceSimule: ServiceNotifications {
    private var boite: MagasinSimuleCS<[NotificationRecue]> {
        MagasinSimuleCS.de(self) { BoiteSimulee.initiale(nombre: self.reglagesBoite.valeur.nombre) }
    }

    private var reglagesBoite: MagasinSimuleCS<ReglagesBoiteSimulee> { MagasinSimuleCS.de(self) { .init() } }

    /// Pour jouer une grande sélection (#118), avant la première lecture : `nombre` alertes
    /// dans la boîte — plus qu'UNE requête n'en supprime — et la suppression groupée de rang
    /// `suppressionEnPanne` (1 : la première requête) perd le réseau. Aux tests d'interface :
    /// `-notifications <nombre>` et `-panne-suppression <rang>` (`LancementSimule`).
    func reglerNotifications(nombre: Int? = nil, suppressionEnPanne: Int? = nil) {
        reglagesBoite.modifier { ($0.nombre, $0.suppressionEnPanne) = (nombre, suppressionEnPanne) }
    }

    func notifications(_ installation: Installation) async throws -> [NotificationRecue] {
        try await Task.sleep(for: .milliseconds(350))
        return boite.valeur
    }

    func marquerLue(_ id: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(150))
        boite.modifier { $0 = $0.map { var n = $0; if n.id == id { n.lue = true }; return n } }
    }

    func toutMarquerLu(_ installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(200))
        boite.modifier { $0 = $0.map { var n = $0; n.lue = true; return n } }
    }

    func supprimerNotification(_ id: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(150))
        boite.modifier { $0.removeAll { $0.id == id } }
    }

    /// Comme le serveur : hors des bornes du contrat (`SuppressionNotifications.ids`, de 1
    /// à `maxItems`), la requête est refusée en 422 et rien n'est supprimé — ce que
    /// `ServiceAPI` rend `ErreurService.inattendue(422)`.
    func supprimerNotifications(_ ids: Set<Int>, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(200))
        guard (1...LimitesNotifications.selectionParRequete).contains(ids.count) else {
            throw ErreurService.inattendue(422)
        }
        let enPanne = reglagesBoite.modifier { reglages in
            reglages.suppressions += 1
            return reglages.suppressions == reglages.suppressionEnPanne
        }
        if enPanne { throw ErreurService.horsLigne }
        boite.modifier { $0.removeAll { ids.contains($0.id) } }
    }

    func supprimerLues(_ installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(200))
        boite.modifier { $0.removeAll(where: \.lue) }
    }
}

/// Ce que `reglerNotifications` a demandé, et le rang de la dernière suppression groupée.
private struct ReglagesBoiteSimulee {
    var nombre: Int?
    var suppressionEnPanne: Int?
    var suppressions = 0
}
#endif
