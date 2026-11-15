// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// **Accès : site ou application** (coprofirst#2726, contrat 1.31.0) — les vues de la
/// période par canal d'accès (site web, app iPhone, plus tard app Android), et celles de
/// chaque page du palmarès. Le serveur calcule tout : libellés, parts en %, utilisateurs ;
/// l'app les montre tels quels (`standards/09` §8, `CanauxAcces.svelte` du site).
struct PartCanal: Hashable, Sendable, Identifiable {
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
struct VuesCanal: Hashable, Sendable, Identifiable {
    var canal: String
    var libelle: String
    var vues: Int
    var id: String { canal }
}

extension PartCanal {
    init(_ lu: Components.Schemas.PartCanal) {
        self.init(canal: lu.canal, libelle: lu.libelle, vues: lu.vues, part: lu.part, visiteurs: lu.visiteurs)
    }
}

extension VuesCanal {
    init(_ lu: Components.Schemas.VuesCanal) { self.init(canal: lu.canal, libelle: lu.libelle, vues: lu.vues) }
}

extension TableauTelemetrie {
    /// La colonne « Accès » du palmarès n'a de sens qu'avec PLUSIEURS canaux sur la
    /// période : « Site web » sur chaque ligne ne dirait rien (`TopPages.svelte`).
    var plusieursCanauxParPage: Bool {
        Set(topPages.flatMap { $0.canaux.map(\.canal) }).count > 1
    }
}
