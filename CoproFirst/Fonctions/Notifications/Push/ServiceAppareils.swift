// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// L'APNs que vise le jeton : celui de développement pour une app signée au poste
/// (`aps-environment: development`), celui de production pour l'archive (TestFlight,
/// App Store) — la colonne `environnement` de la table `appareil` (spec push §6.1).
enum EnvironnementAPNs: String, Sendable {
    case production
    case developpement

    /// L'environnement de CETTE app : la configuration Debug est signée au poste,
    /// Release est celle de l'archive de distribution.
    static var courant: EnvironnementAPNs {
        #if DEBUG
            .developpement
        #else
            .production
        #endif
    }
}

/// Ce que l'app envoie à POST /appareils (`AppareilEnregistre`) : le jeton, l'APNs à
/// viser, l'abonnement opaque — rien d'autre n'est admis par le serveur.
struct AppareilPush: Hashable, Sendable {
    let jeton: JetonAPNs
    let environnement: EnvironnementAPNs
    let abonnement: String
}

/// Les appareils de la personne connectée (spec push §6.2) : l'enregistrer à
/// l'ouverture d'une résidence, le retirer à la déconnexion (#17).
protocol ServiceAppareils: Sendable {
    /// POST /appareils : enregistre ou rafraîchit (`vu_le`) — un appareil que l'app ne
    /// ré-enregistre pas en 60 jours est purgé par l'installation.
    func enregistrerAppareil(_ appareil: AppareilPush, dans installation: Installation) async throws
    /// DELETE /appareils/{abonnement} : l'abonnement d'un autre compte rend 404.
    func retirerAppareil(_ abonnement: String, dans installation: Installation) async throws
}

extension ServiceCoproFirst {
    /// Le service des appareils ; les deux réalisations s'y conforment
    /// (`NotificationsPushTests` le vérifie à la compilation).
    var serviceAppareils: (any ServiceAppareils)? { self as? any ServiceAppareils }
}

extension ServiceAPI: ServiceAppareils {
    func enregistrerAppareil(_ appareil: AppareilPush, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).postAppareils(body: .json(.init(appareil)))
        }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func retirerAppareil(_ abonnement: String, dans installation: Installation) async throws {
        let sortie = try await appeler {
            try await client(installation.adresse).deleteAppareilsAbonnement(path: .init(abonnement: abonnement))
        }
        switch sortie {
        case .noContent: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}

extension Components.Schemas.AppareilEnregistre {
    /// Le corps de POST /appareils — le seul endroit où le jeton quitte sa boîte.
    init(_ appareil: AppareilPush) {
        self.init(
            abonnement: appareil.abonnement,
            environnement: appareil.environnement == .production ? .production : .developpement,
            jeton: appareil.jeton.hexadecimal)
    }
}
