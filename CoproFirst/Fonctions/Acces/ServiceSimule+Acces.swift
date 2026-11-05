// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// « Mes lots & accès » simulé : les réponses du serveur (`FixturesAcces`, en JSON,
/// confrontées au contrat par `FixturesAccesTests`), lues par le même branchement que
/// le service réel.
extension ServiceSimule: ServiceAcces {
    func mesLots(_ installation: Installation) async throws -> [LotDuCompte] {
        try await Task.sleep(for: .milliseconds(300))
        return try FixturesAcces.lots()
    }

    func monBail(_ installation: Installation) async throws -> BailDuLocataire? {
        try await Task.sleep(for: .milliseconds(200))
        return nil  // le compte simulé n'est pas locataire
    }

    func baux(_ installation: Installation, tous: Bool) async throws -> [Bail] {
        try await Task.sleep(for: .milliseconds(300))
        return try FixturesAcces.bauxLus()
    }

    func mesAcces(_ type: TypeAcces, dans installation: Installation) async throws -> [AccesDetenu] {
        try await Task.sleep(for: .milliseconds(300))
        return try AccesSimules.partage.detenus(type)
    }

    func accesRecus(_ installation: Installation) async throws -> [AccesDetenu] {
        try await Task.sleep(for: .milliseconds(200))
        return []
    }

    func demander(_ demande: DemandeAcces, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(450))
        guard let lot = demande.lotId, try FixturesAcces.lots().contains(where: { $0.id == lot }) else {
            // La règle du serveur : un lot qui n'est pas le sien est refusé.
            throw ErreurService.refus(.init(phrase: "Vous n'êtes pas associé à ce lot"))
        }
    }

    func declarer(_ type: TypeAcces, code: String, dans installation: Installation) async throws -> Bool {
        try await Task.sleep(for: .milliseconds(450))
        return try AccesSimules.partage.declarer(type, code: code)
    }

    func signalerPerdu(_ acces: AccesDetenu, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
        AccesSimules.partage.signalerPerdu(acces)
    }

    func recupererAcces(bail: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }
}

/// Les accès simulés, lus des réponses du serveur (`FixturesAcces`) puis changés par
/// les gestes (déclarer, signaler perdu).
final class AccesSimules: @unchecked Sendable {
    static let partage = AccesSimules()
    private let verrou = NSLock()
    private var parType: [TypeAcces: [AccesDetenu]] = [:]

    func detenus(_ type: TypeAcces) throws -> [AccesDetenu] {
        try verrou.withLock {
            if parType[type] == nil { parType[type] = try FixturesAcces.detenus(type) }
            return parType[type] ?? []
        }
    }

    func declarer(_ type: TypeAcces, code: String) throws -> Bool {
        _ = try detenus(.vigik)
        _ = try detenus(.telecommande)
        return try verrou.withLock {
            let tous = parType.values.flatMap { $0 }
            if tous.contains(where: { $0.code == code }) {
                let nom = type == .vigik ? "Vigik" : "Télécommande"
                throw ErreurService.refus(.init(phrase: "\(nom) déjà enregistré sur votre compte"))
            }
            let id = (tous.map(\.id).max() ?? 0) + 1
            parType[type, default: []].append(AccesDetenu(id: id, code: code, statut: "actif", type: type.rawValue))
            return code.hasPrefix("IMPORT")
        }
    }

    func signalerPerdu(_ acces: AccesDetenu) {
        verrou.withLock {
            for (type, liste) in parType {
                parType[type] = liste.map { lu in
                    var marque = lu
                    if lu.id == acces.id { marque.statut = "perdu" }
                    return marque
                }
            }
        }
    }
}
