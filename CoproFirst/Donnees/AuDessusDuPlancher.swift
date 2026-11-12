// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Des champs qu'une route TYPÉE sert au-dessus du plancher — absents du contrat sur
/// lequel l'app se génère, servis par une installation plus récente (#89). L'API simulée
/// les sert à la forme du serveur ; l'écran les relit par `Relecture.auDessusDuPlancher`.
///
/// `scripts/verifier-fixtures.py` les tolère dans ce schéma seulement, et échoue le jour
/// où le contrat les déclare : ils se lisent alors par le type généré, et la déclaration
/// se retire. `contrat` dit la version qui les sert : celle que le plancher doit
/// atteindre.
struct AuDessusDuPlancher: Sendable {
    let schema: String
    let champs: [String]
    let contrat: String
}
