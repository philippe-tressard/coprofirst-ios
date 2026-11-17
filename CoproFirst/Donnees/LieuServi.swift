// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Le LIEU d'un contenu, tel que le serveur le sert (`perimetre_libelle`, contrat 1.24.0,
/// coprofirst#2633, #130) : « Bât. 2 › Toit », `""` pour le périmètre par défaut, que le
/// badge tait (`BadgePerimetre` du site).
///
/// La règle du serveur (`utils/perimetres/libelles.py` : chemins « › », groupes « · » et
/// « — », nœuds d'organisation tus) ne se recopie pas. Le plancher sert le lieu partout :
/// aucun repli (codes nommés par l'arbre, `perimetre_label`) ne reste (#87).
enum LieuServi {
    /// Le lieu à montrer : servi, il fait foi ; `""` (le défaut) ou absent → rien.
    static func lieu(_ servi: String?) -> String? {
        servi.flatMap { $0.isEmpty ? nil : $0 }
    }
}
