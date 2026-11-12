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
    /// GET /admin/maintenance/sante → `SanteMaintenance` (typé depuis le contrat 1.16.0,
    /// coprofirst#2618).
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
        var creeLe: Date?
        var erreur: String?
    }
}

extension SanteTaches {
    init(_ lu: Components.Schemas.SanteMaintenance) {
        self.init(
            taches: lu.taches.map(Tache.init), anomaliesRecentes: lu.anomaliesRecentes.map(Anomalie.init),
            anomaliesFenetreJours: lu.anomaliesFenetreJours)
    }
}

extension SanteTaches.Tache {
    init(_ lu: Components.Schemas.SanteTache) {
        self.init(
            tache: lu.tache, statut: lu.statut, noeud: lu.noeud, derniere: lu.derniere, retardHeures: lu.retardHeures,
            noeudEnRetard: lu.noeudEnRetard, statutEnRetard: lu.statutEnRetard)
    }
}

extension SanteTaches.Anomalie {
    init(_ lu: Components.Schemas.AnomalieRecente) {
        self.init(tache: lu.tache, noeud: lu.noeud, creeLe: lu.creeLe, erreur: lu.erreur)
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
