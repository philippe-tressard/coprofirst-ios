// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que l'onglet « Badges & télécommandes » demande à une installation (#15) : le
/// parc de la copropriété, badges Vigik et télécommandes confondus — un RÉFÉRENTIEL
/// qu'on consulte (`pages-roles.ts`). Le serveur refuse ces routes à qui n'est pas du
/// conseil. Ce qu'un accès ouvre est nommé par le serveur (`perimetre_libelle`, #130).
protocol ServiceBadgesCS: Sendable {
    /// GET /acces/admin/vigiks et /acces/admin/telecommandes.
    func parc(_ installation: Installation) async throws -> [AccesDuParc]
}

extension ContexteOnglet {
    var serviceBadges: (any ServiceBadgesCS)? { service as? any ServiceBadgesCS }
}

/// Un badge ou une télécommande de la copropriété (`AccesAdminOut`).
struct AccesDuParc: Hashable, Sendable, Identifiable {
    let type: TypeAcces
    let numero: Int
    var code: String
    var porteurNom: String
    /// Le rang du porteur parmi tous les comptes, nom PUIS prénom, comparable entre
    /// Vigik et télécommandes (#55) : le tri « par porteur » le lit, jamais `porteurNom`
    /// (qui commence par le prénom). Sans porteur (`porteurId` nul) : en dernier.
    var porteurRang: Int
    var porteurId: Int?
    var lotLibelle: String?
    var statut: String
    var chezLocataire: Bool
    /// Ce que l'accès ouvre, nommé par le serveur (`perimetre_libelle`, #130) — rien pour
    /// le périmètre par défaut (`LieuServi`).
    var lieu: String?

    var id: String { "\(type.rawValue)-\(numero)" }

    /// L'ordre « par porteur » du site : le rang servi, les lignes sans porteur en dernier.
    static func parPorteur(_ a: AccesDuParc, _ b: AccesDuParc) -> Bool {
        ((a.porteurId == nil) ? 1 : 0, a.porteurRang) < ((b.porteurId == nil) ? 1 : 0, b.porteurRang)
    }
}

extension ServiceAPI: ServiceBadgesCS {
    func parc(_ installation: Installation) async throws -> [AccesDuParc] {
        let client = client(installation.adresse)
        async let vigiks = appeler { try await client.getAccesAdminVigiks() }
        async let telecommandes = appeler { try await client.getAccesAdminTelecommandes() }
        return try Self.lus(await vigiks) + Self.lus(await telecommandes)
    }

    private static func lus(_ servie: Operations.GetAccesAdminVigiks.Output) throws -> [AccesDuParc] {
        switch servie {
        case .ok(let ok): return try ok.body.json.map { AccesDuParc(.vigik, $0) }
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    private static func lus(_ servie: Operations.GetAccesAdminTelecommandes.Output) throws -> [AccesDuParc] {
        switch servie {
        case .ok(let ok): return try ok.body.json.map { AccesDuParc(.telecommande, $0) }
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}

extension AccesDuParc {
    /// L'accès servi, par son type GÉNÉRÉ — le même branchement pour le service réel et
    /// l'API simulée ; son type est celui de la route qui l'a servi.
    init(_ type: TypeAcces, _ acces: Components.Schemas.AccesAdminOut) {
        self.init(
            type: type, numero: acces.id, code: acces.code, porteurNom: acces.porteurNom,
            porteurRang: acces.porteurRang, porteurId: acces.porteurId, lotLibelle: acces.lotLibelle,
            statut: acces.statut.rawValue, chezLocataire: acces.chezLocataire,
            lieu: LieuServi.lieu(acces.perimetreLibelle))
    }
}

#if DEBUG
extension ServiceSimule: ServiceBadgesCS {
    func parc(_ installation: Installation) async throws -> [AccesDuParc] {
        try await Task.sleep(for: .milliseconds(350))
        return try FixturesBadgesCS.parcLu()
    }
}
#endif
