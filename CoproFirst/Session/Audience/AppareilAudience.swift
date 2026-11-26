// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.126.5 (commit 62852e89915e6bfaf695125a8cca5affa72abdcf), api/app/utils/canaux_audience.py#APPAREILS_PAR_CANAL (constantes-clients.json).

import Foundation

/// Les classes d'appareil que le canal `ios` déclare à POST /telemetry/collect (`LotAudience.appareil`) :
/// une catégorie, jamais un modèle ni une version de système (coprofirst#2774).
enum AppareilAudience: String, CaseIterable, Sendable {
    case iphone
    case ipad
    case mac
    case appleTv = "apple_tv"
    case appleWatch = "apple_watch"
    case vision
}
