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
    /// La résidence n'a pas répondu (réseau, serveur) : rien de gardé dans ce lot — la
    /// dernière lecture datée vient avec la liaison, comme sur l'iPhone (#101).
    case injoignable
}

/// D'où la montre lit les alertes.
enum SourceDeLaCloche: Equatable, Sendable {
    /// Liaison éteinte (#226, lot 1) : aucune résidence à lire — la lecture échoue, et la
    /// montre dirait « injoignable ». Le cas existe pour que le type ne soit pas VIDE en
    /// Release, où `simulee` n'existe pas : un type sans valeur ne se compile pas hors
    /// optimisation globale (#292). La résidence reliée le remplace au lot de la liaison.
    case aucune
    #if DEBUG
    /// Une résidence inventée (`-api-simulee`) : la boîte de l'iPhone simulé.
    case simulee(ClocheSimulee.Reglage)
    #endif

    func alertes() async throws -> [NotificationRecue] {
        switch self {
        case .aucune: throw LiaisonEteinte()
        #if DEBUG
        case .simulee(let reglage): try await ClocheSimulee.alertes(reglage)
        #endif
        }
    }
}

/// La lecture d'une montre que rien ne relie (`SourceDeLaCloche.aucune`).
struct LiaisonEteinte: Error {}
