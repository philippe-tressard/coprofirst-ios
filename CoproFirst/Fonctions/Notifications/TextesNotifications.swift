// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Les textes de la cloche, écrits une fois — ceux du site (`notifications/+page.svelte`).
/// L'iPhone et la montre les lisent ici (#226).
enum TextesNotifications {
    static let titre = "Notifications"
    static let aujourdhui = "Aujourd'hui"
    static let anciennes = "Plus anciennes"
    static let toutMarquerLu = "Tout marquer lu"
    static let marquerLu = "Marquer lu"
    static let urgent = "Urgent"
    static let vide = "Aucune notification"
    static let videDetail = "Vous êtes à jour !"
    static let confirmerTitre = "Supprimer définitivement"
    static let supprimer = "Supprimer"
    static let supprimerLues = "Supprimer les lues"
    static let luesSupprimees = "Notifications lues supprimées"
    static let modifier = "Modifier"
    static let terminer = "OK"
    static let toutSelectionner = "Tout sélectionner"
    static let toutDeselectionner = "Tout désélectionner"

    /// « Supprimer », puis « Supprimer (3) » dès qu'une sélection existe.
    static func supprimerSelection(_ nombre: Int) -> String {
        nombre == 0 ? supprimer : "\(supprimer) (\(nombre))"
    }

    /// « 1 non lue », « 3 non lues ».
    static func nonLues(_ nombre: Int) -> String {
        nombre > 1 ? "\(nombre) non lues" : "\(nombre) non lue"
    }

    /// Une sélection interrompue en route (#118) : ce qui est parti, ce qui demeure —
    /// « 500 notifications sur 1200 ont été supprimées ; les 700 autres sont toujours là. »
    static func suppressionInterrompue(_ parties: Int, sur total: Int) -> String {
        let reste = total - parties
        let fait =
            parties > 1
            ? "\(parties) notifications sur \(total) ont été supprimées"
            : "\(parties) notification sur \(total) a été supprimée"
        let demeure = reste > 1 ? "les \(reste) autres sont toujours là" : "la dernière est toujours là"
        return "\(fait) ; \(demeure)."
    }
}
