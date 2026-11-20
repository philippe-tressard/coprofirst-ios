// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// La cloche d'une résidence inventée, pour les tests et les captures : les MÊMES alertes
/// que l'iPhone simulé (`BoiteSimulee`), aucune requête. Arguments de lancement :
/// `-api-simulee`, et `-cloche vide|injoignable|refusee|horsligne|<nombre>`.
enum ClocheSimulee {
    static let residence = "Résidence des Tilleuls"
    /// Une adresse réservée aux exemples : aucune requête n'y part.
    static let adresse = URL(string: "https://tilleuls.example.com")!

    enum Reglage: Hashable, Sendable {
        /// La boîte de l'iPhone simulé, `nombre` alertes en tout (150 sans réglage).
        case boite(nombre: Int?)
        /// Aucune alerte.
        case vide
        /// La résidence ne répond pas.
        case injoignable
        /// Le serveur ne reconnaît plus le jeton : la montre oublie sa liaison (#226).
        case refusee
        /// Sans réseau, sur une cloche gardée il y a deux heures (#226, lot 3).
        case horsLigne
    }

    static func reglage(_ arguments: [String]) -> Reglage {
        guard let rang = arguments.firstIndex(of: "-cloche"), arguments.indices.contains(rang + 1) else {
            return .boite(nombre: nil)
        }
        switch arguments[rang + 1] {
        case "vide": return .vide
        case "injoignable": return .injoignable
        case "refusee": return .refusee
        case "horsligne": return .horsLigne
        case let valeur: return .boite(nombre: Int(valeur))
        }
    }

    /// La garde de la simulation : vide, ou, sous `-cloche horsligne`, la boîte simulée lue
    /// il y a deux heures.
    static func garde(_ arguments: [String]) -> GardeEnMemoire {
        guard reglage(arguments) == .horsLigne else { return GardeEnMemoire() }
        return GardeEnMemoire(
            ClocheGardee(adresse: adresse, alertes: BoiteSimulee.initiale(nombre: nil), aJourAu: .now - 7_200))
    }

    static func alertes(_ reglage: Reglage) async throws -> [NotificationRecue] {
        try await Task.sleep(for: .milliseconds(350))
        switch reglage {
        case .boite(let nombre): return BoiteSimulee.initiale(nombre: nombre)
        case .vide: return []
        case .injoignable, .horsLigne: throw URLError(.notConnectedToInternet)
        case .refusee: throw JetonRefuse()
        }
    }
}
#endif
