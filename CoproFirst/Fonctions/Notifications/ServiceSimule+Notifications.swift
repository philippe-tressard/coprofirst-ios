// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Des alertes inventées, pour les aperçus, les tests et les captures : aucune
/// personne, aucune requête. Leur état (lue, supprimée) vit le temps du service.
extension ServiceSimule: ServiceNotifications {
    private var boite: MagasinSimuleCS<[NotificationRecue]> { MagasinSimuleCS.de(self) { BoiteSimulee.initiale() } }

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
}

/// Les notifications de départ. Chaque service simulé garde les siennes dans un
/// `MagasinSimuleCS`, qui retient le service : une adresse libérée puis réemployée par
/// un autre service (les tests en créent beaucoup) ne lui rend plus la boîte d'un autre.
private enum BoiteSimulee {
    static func initiale() -> [NotificationRecue] {
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
        ] + anciennes(il)
    }

    /// Le volume d'un compte réel (146 alertes sur l'iPhone de Philippe, 05/11/2026) :
    /// 146 alertes plus anciennes, une sur quinze non lue — 150 en tout, 12 non lues.
    static let nombreAnciennes = 146

    private static func anciennes(_ il: (Double) -> Date) -> [NotificationRecue] {
        // Les modèles : type, titre, corps.
        let modeles = [
            ["ticket", "Votre affaire avance", "<p>Une affaire que vous suivez a changé de statut.</p>"],
            ["publication", "Nouvelle actualité", "<p>Le conseil syndical a publié une information.</p>"],
            ["sondage", "Sondage clôturé", "<p>Les résultats sont visibles dans la Communauté.</p>"],
            ["document", "Nouveau document", "<p>Un procès-verbal a été ajouté à la résidence.</p>"],
        ]
        return (0..<nombreAnciennes).map { rang in
            let modele = modeles[rang % modeles.count]
            return NotificationRecue(
                id: 100 + rang, type: modele[0], titre: modele[1], corps: modele[2],
                lue: !rang.isMultiple(of: 15), urgente: false, creeLe: il(24 * 7 + Double(rang) * 12))
        }
    }
}
