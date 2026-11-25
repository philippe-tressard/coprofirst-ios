// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Les montres de l'installation simulée, à la forme du serveur (`auth/jetons_montre`,
/// `routers/montres`, v3.108.0) : un jeton neuf à chaque émission et à chaque renouvellement,
/// 30 jours ; au-delà de 4 montres, les plus anciennes sont retirées ; une montre inconnue
/// rend 404 « Montre introuvable » ; sans session, 401 comme `get_current_user`.
struct MontresSimulees: Sendable {
    /// Par hôte, l'échéance de chaque montre, rangée par identifiant (croissant = plus récente).
    var parHote: [String: [Int: Date]] = [:]
    var prochainId = 1
    /// Le jeton brut que chaque montre a reçu en dernier — ce que la montre simulée lirait.
    var jetons: [Int: String] = [:]

    static let dureeJours = 30
    static let parCompte = 4
}

extension ServiceSimule: ServiceMontres {
    private var montres: MagasinSimuleCS<MontresSimulees> { MagasinSimuleCS.de(self) { MontresSimulees() } }

    /// Les montres que l'installation simulée connaît pour cet hôte — lu par les tests.
    func montresReliees(_ installation: Installation) -> [Int] {
        (montres.valeur.parHote[installation.hote] ?? [:]).keys.sorted()
    }

    func emettreMontre(dans installation: Installation) async throws -> JetonDeMontre {
        try await Task.sleep(for: .milliseconds(100))
        try exigerSession(installation)
        return montres.modifier { magasin in
            let id = magasin.prochainId
            magasin.prochainId += 1
            var table = magasin.parHote[installation.hote] ?? [:]
            table[id] = Self.echeance()
            for ancienne in table.keys.sorted().dropLast(MontresSimulees.parCompte) { table[ancienne] = nil }
            magasin.parHote[installation.hote] = table
            return Self.jeton(id, table[id] ?? .now, &magasin)
        }
    }

    func renouvelerMontre(_ id: Int, dans installation: Installation) async throws -> JetonDeMontre {
        try await Task.sleep(for: .milliseconds(100))
        try exigerSession(installation)
        let jeton = montres.modifier { magasin -> JetonDeMontre? in
            guard magasin.parHote[installation.hote]?[id] != nil else { return nil }
            let echeance = Self.echeance()
            magasin.parHote[installation.hote]?[id] = echeance
            return Self.jeton(id, echeance, &magasin)
        }
        guard let jeton else { throw ErreurService.introuvable }
        return jeton
    }

    func retirerMontre(_ id: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(100))
        try exigerSession(installation)
        let retiree = montres.modifier { $0.parHote[installation.hote]?.removeValue(forKey: id) }
        if retiree == nil { throw ErreurService.refus(.init(phrase: "Montre introuvable")) }
    }

    private static func echeance() -> Date {
        Date.now.addingTimeInterval(Double(MontresSimulees.dureeJours) * 86_400)
    }

    private static func jeton(_ id: Int, _ echeance: Date, _ magasin: inout MontresSimulees) -> JetonDeMontre {
        let brut = "jeton-simule-\(id)-\(UUID().uuidString)"
        magasin.jetons[id] = brut
        return JetonDeMontre(id: id, jeton: JetonMasque(brut), expireLe: echeance)
    }
}
#endif
