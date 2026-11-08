// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Une alerte reçue, telle que GET /notifications la sert (`NotificationRead`).
struct NotificationRecue: Hashable, Sendable, Identifiable {
    let id: Int
    let type: String
    let titre: String
    /// Du HTML de l'éditeur : il passe par `TexteDuSite`.
    let corps: String
    var lue: Bool
    let urgente: Bool
    let creeLe: Date
}

/// Ce que l'écran des notifications demande à une installation (#14).
protocol ServiceNotifications: Sendable {
    /// GET /notifications : toutes, les plus récentes d'abord (le serveur trie).
    func notifications(_ installation: Installation) async throws -> [NotificationRecue]
    /// PATCH /notifications/{id}/lue.
    func marquerLue(_ id: Int, dans installation: Installation) async throws
    /// POST /notifications/tout-marquer-lu.
    func toutMarquerLu(_ installation: Installation) async throws
    /// DELETE /notifications/{id} — définitif, comme sur le site.
    func supprimerNotification(_ id: Int, dans installation: Installation) async throws
    /// POST /notifications/supprimer-selection — celles choisies, en UNE requête (#53).
    /// Un identifiant qui n'est pas une alerte du compte est ignoré par le serveur.
    func supprimerNotifications(_ ids: Set<Int>, dans installation: Installation) async throws
    /// POST /notifications/supprimer-lues — toutes les lues du compte, en une requête.
    func supprimerLues(_ installation: Installation) async throws
}

extension Parcours {
    /// Le service des notifications : les deux réalisations s'y conforment
    /// (`NotificationsTests` le vérifie à la compilation).
    var serviceNotifications: any ServiceNotifications {
        // swiftlint:disable:next force_cast
        service as! any ServiceNotifications
    }
}

extension ServiceAPI: ServiceNotifications {
    func notifications(_ installation: Installation) async throws -> [NotificationRecue] {
        let sortie = try await appeler {
            try await client(installation.adresse).getNotifications()
        }
        switch sortie {
        case .ok(let ok): return try ok.body.json.map(NotificationRecue.init(lue:))
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func marquerLue(_ id: Int, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).patchNotificationsNotifIdLue(path: .init(notifId: id))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func toutMarquerLu(_ installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).postNotificationsToutMarquerLu()
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func supprimerNotification(_ id: Int, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).deleteNotificationsNotifId(
                path: .init(notifId: id))
        }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func supprimerNotifications(_ ids: Set<Int>, dans installation: Installation) async throws {
        let corps = Components.Schemas.SuppressionNotifications(ids: ids.sorted())
        let sortie = try await appeler {
            try await client(installation.adresse).postNotificationsSupprimerSelection(body: .json(corps))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func supprimerLues(_ installation: Installation) async throws {
        let sortie = try await appeler { try await client(installation.adresse).postNotificationsSupprimerLues() }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}

extension NotificationRecue {
    init(lue notification: Components.Schemas.NotificationRead) {
        self.init(
            id: notification.id, type: notification._type, titre: notification.titre, corps: notification.corps,
            lue: notification.lue, urgente: notification.urgente, creeLe: notification.creeLe)
    }
}
