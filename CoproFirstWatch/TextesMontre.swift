// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Les textes de la montre, écrits une fois — ceux du périmètre arrêté dans #226, que la
/// montre Wear OS reprend (« l'iPhone » y devient « le téléphone »). « Urgent » est celui de
/// la cloche de l'iPhone (`TextesNotifications`).
enum TextesMontre {
    static let nonReliee = "Ouvrez CoproFirst sur l'iPhone pour relier la montre"
    static let aucuneAlerte = "Aucune alerte"
    static let dejaLues = "Déjà lues"
    static let repliees = "Repliées"
    static let depliees = "Dépliées"
    static let chargement = "Chargement des alertes"
    static let injoignable = "La résidence ne répond pas"
    static let reessayer = "Réessayer"
    static let nonLue = "Non lue"

    // Le widget (#226), comme la tuile et la complication de Wear OS.
    static let widgetNom = "Alertes"
    static let widgetDescription = "Le nombre de nouvelles alertes de la résidence, sans leur contenu"
    static let complicationNonLu = "CoproFirst, nouvelles alertes"
    static let complicationRien = "CoproFirst"

    static func nouvellesAlertes(_ nombre: Int) -> String {
        nombre == 1 ? "1 nouvelle alerte" : "\(FormatsDuSite.nombre(nombre)) nouvelles alertes"
    }

    static func dontUrgentes(_ nombre: Int) -> String {
        nombre == 1 ? "dont 1 urgente" : "dont \(FormatsDuSite.nombre(nombre)) urgentes"
    }
}
