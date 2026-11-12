// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que la route accepte de CE lecteur sur UNE entrée de l'Historique, tel que le
/// serveur le sert avec elle (`TicketEvolutionRead.peut_modifier`, `.peut_supprimer`,
/// contrat 1.19.0, coprofirst#2646) : lu, jamais recalculé ici (`standards/09` §8).
/// Un champ absent — une installation antérieure — vaut « non » : aucun geste offert.
struct DroitsServisSuite: Hashable, Sendable {
    /// ✏️ Corriger l'entrée (PATCH /tickets/{id}/evolutions/{evol_id}).
    var modifier = false
    /// 🗑️ L'effacer du fil (DELETE, même route) : l'administrateur, sur une entrée saisie.
    var supprimer = false
}

/// Les gestes que GET /tickets/{id}/evolutions sert au-dessus du plancher, par entrée
/// (contrat 1.19.0, #93), relus par `Relecture.auDessusDuPlancher` : tout est facultatif.
struct GestesSuiteAuDessusDuPlancher: Decodable, Identifiable {
    let id: Int
    var peutModifier: Bool?
    var peutSupprimer: Bool?
}

extension [SuiteAffaire] {
    /// Les mêmes entrées, chacune avec les gestes que le corps servi annonce pour elle —
    /// le MÊME branchement pour le service réel et l'API simulée. Un corps qui ne les
    /// sert pas, ou qui ne se lit pas : aucun geste (défaut fermé).
    func avecGestesServis(corps: Data?) -> [SuiteAffaire] {
        self
    }
}
