// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que l'onglet « Courriels affaires » de l'Espace CS demande (#15) : le journal de
/// la relève des messages reçus à l'adresse des affaires (coprofirst#1447). Jamais le
/// texte d'un message ; l'expéditeur n'est lu en entier que par l'administrateur — le
/// serveur ne l'envoie pas au conseil.
protocol ServiceCourrielsCS: Sendable {
    /// GET /courriels-affaires — réponse typée (`JournalCourriels`).
    func journalCourriels(_ installation: Installation) async throws -> JournalCourriels
}

extension ContexteOngletCS {
    var serviceCourriels: (any ServiceCourrielsCS)? { service as? any ServiceCourrielsCS }
}

struct JournalCourriels: Hashable, Sendable {
    /// Le nombre de messages que le journal garde (paramètre du site).
    var limite: Int
    var messages: [CourrielReleve]
}

struct CourrielReleve: Hashable, Sendable, Identifiable {
    let id: Int
    var releveLe: Date
    var envoyeLe: Date?
    var expediteur: String
    var objet: String
    /// `accepte`, `relance`, `refuse` ou `ignore` (`TablesCourriels.verdicts`).
    var decision: String
    var motif: String
    var ticketId: Int?
    /// Le numéro de l'affaire (`TK-E00066`), quand le message en a rejoint une.
    var affaire: String?

    var verdict: LibelleTeinte { TablesCourriels.verdicts[decision] ?? .brut(decision) }
}
