// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import UIKit

/// Ce que l'appareil dit de lui-même, lu une fois (`actuels`) : la fonction qui en tire la
/// classe déclarée à la mesure d'audience (`AppareilAudience.deduire`, #229) reste pure, et
/// se teste sans l'appareil.
struct FaitsAppareil: Equatable, Sendable {
    /// La cible tvOS — l'écran de hall (#218), qui n'envoie pas encore la mesure.
    var tele = false
    /// Une app iPhone ouverte sur un Mac à puce Apple (`isiOSAppOnMac`).
    var surMac = false
    /// Une app iPhone ouverte sur Vision Pro (`isiOSAppOnVision`, iOS 26.1 ; avant, l'idiome).
    var surVision = false
    /// `UIDevice.model` : « iPhone », « iPad » — la famille, jamais le modèle précis.
    var modele = ""

    /// Les faits de CET appareil.
    @MainActor static var actuels: FaitsAppareil {
        let processus = ProcessInfo.processInfo
        var surVision = UIDevice.current.userInterfaceIdiom == .vision
        if #available(iOS 26.1, *) { surVision = surVision || processus.isiOSAppOnVision }
        #if os(tvOS)
        let tele = true
        #else
        let tele = false
        #endif
        return FaitsAppareil(
            tele: tele, surMac: processus.isiOSAppOnMac, surVision: surVision, modele: UIDevice.current.model)
    }
}

extension AppareilAudience {
    /// La classe d'appareil que déclare l'app, des faits de l'appareil — la plus précise
    /// d'abord : une app iPhone sur Mac ou sur Vision Pro n'est ni un iPhone ni un iPad.
    ///
    /// ⚠️ L'iPad se lit dans le MODÈLE : en mode compatibilité, l'idiome reste `.phone`.
    /// `appleWatch` attend une montre qui envoie la mesure (la cible watchOS ne l'envoie pas).
    static func deduire(_ faits: FaitsAppareil) -> AppareilAudience {
        if faits.tele { return .appleTv }
        if faits.surMac { return .mac }
        if faits.surVision { return .vision }
        if faits.modele.hasPrefix("iPad") { return .ipad }
        return .iphone
    }
}
