// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

/// Les textes des Courriels affaires, écrits une fois : ceux de `OngletCourriels.svelte`
/// (coprofirst v3.61.0) ; la vue et les tests les lisent ici.
enum TextesCourriels {
    static let aucun = "Aucun message relevé pour l’instant."
    static let sansObjet = "(sans objet)"
    static let rafraichir = "Rafraîchir la liste des courriels"
    static let deplier = "Montre l’expéditeur et le motif"
    static let replier = "Replie le message"

    static func aide(_ limite: Int) -> String {
        "Les \(FormatsDuSite.nombre(limite)) derniers messages reçus à l'adresse des affaires, du plus récent au "
            + "plus ancien. Un message refusé n'est pas perdu : corrigez ce que le motif indique (le plus souvent le "
            + "numéro d'affaire dans l'objet), puis transférez-le de nouveau."
    }

    /// « Cabinet Syndic · envoyé le 10/04/2026 14:30 ».
    static func sousTitre(_ message: CourrielReleve) -> String {
        guard let envoye = message.envoyeLe else { return message.expediteur }
        return "\(message.expediteur) · envoyé le \(FormatsDuSite.dateHeureCourte(envoye))"
    }

    static func affaire(_ numero: String?) -> String { "Affaire #\(numero ?? "")" }
}
