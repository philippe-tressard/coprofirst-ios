// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que l'onglet « Télémétrie » demande à une installation (#16) : le tableau de bord
/// d'une vue, avec ou sans le gestionnaire du site. Réservé à l'administration
/// (`require_admin`). Réalisé par `ServiceAPI` (client généré) et `ServiceSimule`.
protocol ServiceTelemetrie: Sendable {
    /// GET /telemetry/dashboard → `TableauTelemetrie` (typé depuis le contrat 1.16.0, #87).
    func tableauTelemetrie(
        _ installation: Installation, portee: PorteeTelemetrie, sansGestionnaire: Bool
    ) async throws -> TableauTelemetrie
}

extension ContexteOnglet {
    var serviceTelemetrie: (any ServiceTelemetrie)? { service as? any ServiceTelemetrie }
}

/// Les quatre vues du site : le jour, 30 jours, 12 mois, 10 ans par année.
enum PorteeTelemetrie: String, CaseIterable, Identifiable, Sendable {
    case jour, mois, annee, total
    var id: Self { self }
}

/// Le tableau de bord, tel que le serveur le sert (`utils/telemetrie_tableau`) — ce que
/// l'app en montre : les nombres clés, le graphe, les pages et les utilisateurs actifs.
/// Le reste (erreurs, « Qui vient », retour des comptes, gestes, arrivées, durées) se
/// lit sur le site.
struct TableauTelemetrie: Hashable, Sendable {
    var scope: String
    var kpi: Indicateurs
    var chart: [Baton]
    var chartLabel: String
    var topPages: [PageVue]
    var topUsers: [UtilisateurActif]
    var filtreGestionnaire: FiltreGestionnaire

    /// Les nombres clés : ils changent avec la vue, chacun se lit seul.
    struct Indicateurs: Hashable, Sendable {
        var vues: Int
        var utilisateurs: Int?
        var pages: Int
        var heurePointe: String?
        var moyVuesUtilisateur: Double?
        var moyVuesJour: Double?
        var moyUtilisateursJour: Double?
        var moisActifs: Int?
        var moyVuesMois: Double?
        var anneesActives: Int?
        var moyVuesAn: Double?
        var recordJour: Record?
        var recordMois: Record?
    }

    /// Un record : le jour (ou le mois) et ses utilisateurs uniques.
    struct Record: Hashable, Sendable {
        var uniques: Int
        var jour: String?
        var mois: String?
    }

    /// Un bâton : une heure, un jour (« MM-JJ »), un mois (« AAAA-MM ») ou une année.
    struct Baton: Hashable, Sendable, Identifiable {
        var label: String
        var total: Int
        var uniques: Int?
        var id: String { label }
    }

    struct PageVue: Hashable, Sendable, Identifiable {
        var page: String
        var total: Int
        var uniques: Int
        var id: String { page }
    }

    struct UtilisateurActif: Hashable, Sendable {
        var nom: String
        var statut: String?
        var total: Int
        var pages: Int
        var derniereConnexion: Date?
    }

    /// Ce que le serveur dit du filtre « sans le gestionnaire du site ».
    struct FiltreGestionnaire: Hashable, Sendable {
        /// Proposé seulement s'il changerait quelque chose.
        var propose: Bool
        var gestionnaireDesigne: Bool
        /// « avec » ou « sans » : ce qui a été APPLIQUÉ.
        var applique: String
        var nonDistingueJusquAu: String?
    }
}

extension TableauTelemetrie {
    /// Le tableau servi, par son type GÉNÉRÉ — le même branchement pour le service réel
    /// et l'API simulée.
    init(_ lu: Components.Schemas.TableauTelemetrie) {
        let filtre = lu.filtreGestionnaire
        self.init(
            scope: lu.scope, kpi: Indicateurs(lu.kpi),
            chart: lu.chart.map { Baton(label: $0.label, total: $0.total, uniques: $0.uniques) },
            chartLabel: lu.chartLabel,
            topPages: lu.topPages.map { PageVue(page: $0.page, total: $0.total, uniques: $0.uniques) },
            topUsers: lu.topUsers.map {
                UtilisateurActif(
                    nom: $0.nom, statut: $0.statut, total: $0.total, pages: $0.pages,
                    derniereConnexion: $0.derniereConnexion)
            },
            filtreGestionnaire: FiltreGestionnaire(
                propose: filtre.propose, gestionnaireDesigne: filtre.gestionnaireDesigne, applique: filtre.applique,
                nonDistingueJusquAu: filtre.nonDistingueJusquAu))
    }
}

extension TableauTelemetrie.Indicateurs {
    init(_ lu: Components.Schemas.IndicateursTelemetrie) {
        self.init(
            vues: lu.vues, utilisateurs: lu.utilisateurs, pages: lu.pages, heurePointe: lu.heurePointe,
            moyVuesUtilisateur: lu.moyVuesUtilisateur, moyVuesJour: lu.moyVuesJour,
            moyUtilisateursJour: lu.moyUtilisateursJour, moisActifs: lu.moisActifs, moyVuesMois: lu.moyVuesMois,
            anneesActives: lu.anneesActives, moyVuesAn: lu.moyVuesAn,
            recordJour: lu.recordJour.map(TableauTelemetrie.Record.init),
            recordMois: lu.recordMois.map(TableauTelemetrie.Record.init))
    }
}

extension TableauTelemetrie.Record {
    init(_ lu: Components.Schemas.Record) {
        self.init(uniques: lu.uniques, jour: lu.jour, mois: lu.mois)
    }
}
