// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// **Accès : site ou application** (coprofirst#2726, contrat 1.31.0) — les vues de la
/// période par canal d'accès (site web, app iPhone, plus tard app Android), et celles de
/// chaque page du palmarès. Le serveur calcule tout : libellés, parts en %, utilisateurs ;
/// l'app les montre tels quels (`standards/09` §8, `CanauxAcces.svelte` du site).
///
/// Servis au-dessus du plancher : relus dans le corps servi (`Relecture.auDessusDuPlancher`).
/// Une installation antérieure ne les sert pas — ni bloc ni colonne, comme avant.
struct PartCanal: Hashable, Sendable, Identifiable, Decodable {
    var canal: String
    /// Tel que servi : « Site web », « App iPhone ».
    var libelle: String
    var vues: Int
    /// En pour cent des vues de la période, calculée par le serveur.
    var part: Int
    /// Les comptes venus par ce canal — ne s'additionnent pas d'un canal à l'autre ; `nil`
    /// au-delà des 30 jours d'évènements (Année, Total).
    var visiteurs: Int?
    var id: String { canal }
}

/// Les vues d'une page du palmarès par un canal.
struct VuesCanal: Hashable, Sendable, Identifiable, Decodable {
    var canal: String
    var libelle: String
    var vues: Int
    var id: String { canal }
}

extension TableauTelemetrie {
    /// LA lecture du tableau, pour le service réel comme pour l'API simulée : le type
    /// généré, puis la répartition par canal relue dans `corps` (le corps servi).
    init(_ lu: Components.Schemas.TableauTelemetrie, corps: Data?) {
        self.init(lu)
        guard let servi = Relecture.auDessusDuPlancher(CanauxServis.self, corps: corps) else { return }
        canaux = servi.canaux ?? []
        let parPage = Dictionary(
            (servi.topPages ?? []).map { ($0.page, $0.canaux ?? []) }, uniquingKeysWith: { premier, _ in premier })
        for rang in topPages.indices {
            topPages[rang].canaux = parPage[topPages[rang].page] ?? []
        }
    }

    /// La colonne « Accès » du palmarès n'a de sens qu'avec PLUSIEURS canaux sur la
    /// période : « Site web » sur chaque ligne ne dirait rien (`TopPages.svelte`).
    var plusieursCanauxParPage: Bool {
        Set(topPages.flatMap { $0.canaux.map(\.canal) }).count > 1
    }

    /// Les champs relus, tous facultatifs : rien de servi, rien à montrer.
    private struct CanauxServis: Decodable {
        var canaux: [PartCanal]?
        var topPages: [PageServieParCanal]?
    }
}

/// Une page du palmarès, relue pour ses seuls canaux (`TableauTelemetrie.init(_:corps:)`).
private struct PageServieParCanal: Decodable {
    var page: String
    var canaux: [VuesCanal]?
}
