// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// La cloche telle que la montre la range (périmètre du 16/11/2026, #226) : d'abord les non
/// lues, les URGENTES devant ; puis les déjà lues. Dans chaque groupe, l'ordre du serveur
/// (les plus récentes d'abord) est gardé. La cloche de l'iPhone garde l'ordre du serveur :
/// au poignet, ce qui demande un regard passe devant (divergence déclarée dans #226).
struct Cloche: Equatable, Sendable {
    let nonLues: [NotificationRecue]
    let lues: [NotificationRecue]

    init(_ alertes: [NotificationRecue]) {
        let nonLues = alertes.filter { !$0.lue }
        // Un tri stable : entre deux urgentes, l'ordre du serveur reste.
        self.nonLues = nonLues.filter(\.urgente) + nonLues.filter { !$0.urgente }
        lues = alertes.filter(\.lue)
    }

    /// Les non lues urgentes : le widget les comptera (« dont 1 urgente »).
    var urgentes: Int { nonLues.filter(\.urgente).count }
    var vide: Bool { nonLues.isEmpty && lues.isEmpty }

    func alerte(_ id: Int) -> NotificationRecue? {
        nonLues.first { $0.id == id } ?? lues.first { $0.id == id }
    }
}

/// Ce que la montre sait de la cloche à un instant.
enum LectureCloche: Equatable, Sendable {
    case enCours
    case lue(Cloche)
    /// Sans réseau : la dernière cloche gardée, et l'heure de sa lecture (#226, lot 3).
    case horsLigne(Cloche, aJourAu: Date)
    /// La résidence n'a pas répondu, et rien n'est gardé (ou plus de `LectureGardee.joursMax`).
    case injoignable
}

/// D'où la montre lit les alertes.
enum SourceDeLaCloche: Hashable, Sendable {
    /// La résidence reliée par l'iPhone, lue par son jeton de montre (#226).
    case jeton(LiaisonGardee)
    #if DEBUG
    /// Une résidence inventée (`-api-simulee`) : la boîte de l'iPhone simulé.
    case simulee(ClocheSimulee.Reglage)
    #endif

    /// Lève `JetonRefuse` quand le serveur ne reconnaît plus le jeton.
    func alertes() async throws -> [NotificationRecue] {
        switch self {
        case .jeton(let liaison): try await ClocheParJeton.alertes(liaison)
        #if DEBUG
        case .simulee(let reglage): try await ClocheSimulee.alertes(reglage)
        #endif
        }
    }

    /// L'adresse de la résidence : « Continuer sur l'iPhone », et la cloche gardée.
    var adresse: URL {
        switch self {
        case .jeton(let liaison): liaison.adresse
        #if DEBUG
        case .simulee: ClocheSimulee.adresse
        #endif
        }
    }
}
