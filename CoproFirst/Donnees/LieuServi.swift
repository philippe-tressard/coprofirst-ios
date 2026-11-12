// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Le LIEU d'un contenu, tel que le serveur le sert (`perimetre_libelle`,
/// `perimetre_precise_libelle`, coprofirst#2633, #130) : « Bât. 2 › Toit », `""` pour le
/// périmètre par défaut, que le badge tait (`BadgePerimetre` du site).
///
/// 🔴 L'app ne nomme JAMAIS un lieu elle-même : la règle du serveur
/// (`utils/perimetres/libelles.py` : chemins « › », groupes « · » et « — », nœuds
/// d'organisation tus) ne se recopie pas, et les codes d'un `perimetre_cible` ne se
/// traduisent pas par l'arbre (`scripts/verifier-regles-servies.py` le refuse).
enum LieuServi {
    /// Le lieu à montrer : celui que le serveur sert — rien pour le défaut (`""`), rien
    /// quand il n'en sert pas.
    static func lieu(_ servi: String?) -> String? {
        servi.flatMap { $0.isEmpty ? nil : $0 }
    }
}
