// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que la route accepte de CE lecteur sur UNE entrée de l'Historique, tel que le
/// serveur le sert avec elle (`TicketEvolutionRead.peut_modifier`, `.peut_supprimer`,
/// contrat 1.19.0, coprofirst#2646) : lu par `DetailAffaire.lue`, jamais recalculé ici
/// (`standards/09` §8). Un champ absent — une installation antérieure, au plancher — vaut
/// « non » : aucun geste offert.
struct DroitsServisSuite: Hashable, Sendable {
    /// ✏️ Corriger l'entrée (PATCH /tickets/{id}/evolutions/{evol_id}).
    var modifier = false
    /// 🗑️ L'effacer du fil (DELETE, même route) : l'administrateur, sur une entrée saisie.
    var supprimer = false
}
