// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Des alertes inventées, pour les aperçus, les tests et les captures : aucune
/// personne, aucune requête. Leur état (lue, supprimée) vit le temps du service.
extension ServiceSimule: ServiceNotifications {
    func notifications(_ installation: Installation) async throws -> [NotificationRecue] {
        try await Task.sleep(for: .milliseconds(350))
        return BoiteSimulee.pour(self).lire()
    }

    func marquerLue(_ id: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(150))
        BoiteSimulee.pour(self).modifier { $0 = $0.map { var n = $0; if n.id == id { n.lue = true }; return n } }
    }

    func toutMarquerLu(_ installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(200))
        BoiteSimulee.pour(self).modifier { $0 = $0.map { var n = $0; n.lue = true; return n } }
    }

    func supprimerNotification(_ id: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(150))
        BoiteSimulee.pour(self).modifier { $0.removeAll { $0.id == id } }
    }
}

/// La boîte d'un service simulé — une par instance, pour que deux tests ne se
/// voient pas (une extension ne peut pas ajouter de propriété stockée).
private final class BoiteSimulee: @unchecked Sendable {
    private static let verrouGlobal = NSLock()
    nonisolated(unsafe) private static var boites: [ObjectIdentifier: BoiteSimulee] = [:]

    private let verrou = NSLock()
    private var liste = BoiteSimulee.initiale()

    static func pour(_ service: ServiceSimule) -> BoiteSimulee {
        verrouGlobal.withLock {
            let cle = ObjectIdentifier(service)
            if let boite = boites[cle] { return boite }
            let neuve = BoiteSimulee()
            boites[cle] = neuve
            return neuve
        }
    }

    func lire() -> [NotificationRecue] { verrou.withLock { liste } }

    func modifier(_ geste: (inout [NotificationRecue]) -> Void) { verrou.withLock { geste(&liste) } }

    private static func initiale() -> [NotificationRecue] {
        let maintenant = Date()
        func il(_ heures: Double) -> Date { maintenant.addingTimeInterval(-heures * 3600) }
        return [
            NotificationRecue(
                id: 5, type: "ticket", titre: "Votre affaire avance",
                corps: "<p>L'affaire <strong>« Fuite au 3ème étage »</strong> est passée chez le prestataire.</p>",
                lue: false, urgente: false, creeLe: il(1.5)),
            NotificationRecue(
                id: 4, type: "publication", titre: "Coupure d'eau jeudi matin",
                corps: "<p>L'eau sera coupée de 8 h à 11 h dans les bâtiments A et B.</p>",
                lue: false, urgente: true, creeLe: il(5)),
            NotificationRecue(
                id: 3, type: "sondage", titre: "Nouveau sondage",
                corps: "<p>Quel jour pour la fête des voisins ? Votre avis compte.</p>",
                lue: true, urgente: false, creeLe: il(30)),
            NotificationRecue(
                id: 2, type: "compte", titre: "Compte validé",
                corps: "<p>Le conseil syndical a validé votre compte. Bienvenue !</p>",
                lue: true, urgente: false, creeLe: il(24 * 6)),
        ]
    }
}
