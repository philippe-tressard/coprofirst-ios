// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// Un journal inventé : des objets d'exemple, aucune adresse réelle.
extension ServiceSimule: ServiceCourrielsCS {
    func journalCourriels(_ installation: Installation) async throws -> JournalCourriels {
        try await Task.sleep(for: .milliseconds(350))
        let il = { (heures: Double) in Date.now.addingTimeInterval(-heures * 3_600) }
        return JournalCourriels(
            limite: 50,
            messages: [
                CourrielReleve(
                    id: 41, releveLe: il(2), envoyeLe: il(2.2), expediteur: "Cabinet Syndic Exemple",
                    objet: "RE: [TK-A00012] Fuite au plafond du parking", decision: "accepte",
                    motif: "Réponse versée au fil de l'affaire TK-A00012.", ticketId: 12, affaire: "TK-A00012"),
                CourrielReleve(
                    id: 40, releveLe: il(26), envoyeLe: il(26.5), expediteur: "Camille Essai",
                    objet: "TR: Devis ascenseur TK-E000066", decision: "refuse",
                    motif: "Aucune affaire ne porte le numéro TK-E000066 : vérifiez le numéro dans l'objet.",
                    ticketId: nil, affaire: nil),
                CourrielReleve(
                    id: 39, releveLe: il(30), envoyeLe: nil, expediteur: "Cabinet Syndic Exemple",
                    objet: "Planning des visites d'entretien", decision: "relance",
                    motif: "Sans numéro d'affaire : transmis au conseil syndical.", ticketId: nil, affaire: nil),
                CourrielReleve(
                    id: 38, releveLe: il(50), envoyeLe: il(50), expediteur: "Notification automatique",
                    objet: "", decision: "ignore", motif: "Message automatique (réponse d'absence) : ignoré.",
                    ticketId: nil, affaire: nil),
            ])
    }
}
#endif
