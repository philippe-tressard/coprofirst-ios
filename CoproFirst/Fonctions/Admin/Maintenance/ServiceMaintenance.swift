// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que l'onglet « Maintenance » lit d'une installation (#16) : la santé des tâches
/// planifiées, à l'OPÉRATEUR de la plateforme (`require_operateur`), et le dernier export
/// de la copropriété, à l'ADMINISTRATION (`require_admin`). Chaque lecture n'est offerte
/// qu'au rôle que sa route accepte. Lancer une tâche, vérifier ou lancer un export
/// restent au site. Réalisé par `ServiceAPI` (client généré) et `ServiceSimule`.
protocol ServiceMaintenance: Sendable {
    /// GET /admin/maintenance/sante → `SanteMaintenance` (typée depuis le contrat 1.16.0, #87).
    func santeTaches(_ installation: Installation) async throws -> SanteTaches
    /// GET /admin/export-copropriete/dernier → `DernierExport`.
    func dernierExport(_ installation: Installation) async throws -> DernierExport
}

extension ContexteOnglet {
    var serviceMaintenance: (any ServiceMaintenance)? { service as? any ServiceMaintenance }
}

/// La santé des tâches planifiées, telle que le serveur la juge (`utils/etat_taches`) :
/// une ligne par tâche, son statut, sa dernière exécution — et ce qui a échoué récemment.
/// Les nœuds sont nommés par le SERVEUR : l'app n'en connaît aucun.
struct SanteTaches: Hashable, Sendable {
    var taches: [Tache]
    var anomaliesRecentes: [Anomalie]
    var anomaliesFenetreJours: Int

    struct Tache: Hashable, Sendable, Identifiable {
        var tache: String
        var statut: String
        var noeud: String?
        var derniere: Date?
        var retardHeures: Double?
        var noeudEnRetard: String?
        var statutEnRetard: String?
        var id: String { tache }
    }

    struct Anomalie: Hashable, Sendable {
        var tache: String
        var noeud: String?
        var creeLe: Date
        var erreur: String?
    }
}

extension SanteTaches {
    /// La santé servie, par son type GÉNÉRÉ — le même branchement pour le service réel et
    /// l'API simulée.
    init(_ lue: Components.Schemas.SanteMaintenance) {
        self.init(
            taches: lue.taches.map {
                Tache(
                    tache: $0.tache, statut: $0.statut, noeud: $0.noeud, derniere: $0.derniere,
                    retardHeures: $0.retardHeures, noeudEnRetard: $0.noeudEnRetard, statutEnRetard: $0.statutEnRetard)
            },
            anomaliesRecentes: lue.anomaliesRecentes.map {
                Anomalie(tache: $0.tache, noeud: $0.noeud, creeLe: $0.creeLe, erreur: $0.erreur)
            },
            anomaliesFenetreJours: lue.anomaliesFenetreJours)
    }
}

/// Le dernier export de la copropriété dans le volume des sauvegardes (`DernierExport`) ;
/// sans `archive`, il n'y en a aucun.
struct DernierExport: Hashable, Sendable {
    var archive: String?
    var creeLe: Date?
    var octets: Int
    var tables: Int
    var lignes: Int
    var fichiers: Int
}

extension DernierExport {
    init(_ lu: Components.Schemas.DernierExport) {
        self.init(
            archive: lu.archive, creeLe: FormatsDuSite.lire(lu.creeLe), octets: lu.octets ?? 0, tables: lu.tables ?? 0,
            lignes: lu.lignes ?? 0, fichiers: lu.fichiers ?? 0)
    }
}
