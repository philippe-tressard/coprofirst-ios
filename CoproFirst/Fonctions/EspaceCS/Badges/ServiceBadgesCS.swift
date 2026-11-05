// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que l'onglet « Badges & télécommandes » demande à une installation (#15) : le
/// parc de la copropriété, badges Vigik et télécommandes confondus — un RÉFÉRENTIEL
/// qu'on consulte (`pages-roles.ts`). Le serveur refuse ces routes à qui n'est pas du
/// conseil.
protocol ServiceBadgesCS: Sendable {
    /// GET /acces/admin/vigiks et /acces/admin/telecommandes.
    func parc(_ installation: Installation) async throws -> [AccesDuParc]
}

extension ContexteOngletCS {
    var serviceBadges: (any ServiceBadgesCS)? { service as? any ServiceBadgesCS }
}

/// Un badge ou une télécommande de la copropriété (`AccesAdminOut`).
struct AccesDuParc: Hashable, Sendable, Identifiable {
    let type: TypeAcces
    let numero: Int
    var code: String
    var porteurNom: String
    var lotLibelle: String?
    /// Ce que l'accès ouvre, tel que le serveur le nomme.
    var perimetreCible: [String]
    var statut: String
    var chezLocataire: Bool

    var id: String { "\(type.rawValue)-\(numero)" }
}

extension ServiceAPI: ServiceBadgesCS {
    func parc(_ installation: Installation) async throws -> [AccesDuParc] {
        let client = client(installation.adresse)
        async let vigiks = appeler { try await client.getAccesAdminVigiks() }
        async let telecommandes = appeler { try await client.getAccesAdminTelecommandes() }
        return try Self.lus(.vigik, await vigiks) + Self.lus(.telecommande, await telecommandes)
    }

    private static func lus(
        _ type: TypeAcces, _ sortie: Operations.GetAccesAdminVigiks.Output
    ) throws -> [AccesDuParc] {
        switch sortie {
        case .ok(let ok): return try ok.body.json.map { AccesDuParc(type, $0) }
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    private static func lus(
        _ type: TypeAcces, _ sortie: Operations.GetAccesAdminTelecommandes.Output
    ) throws -> [AccesDuParc] {
        switch sortie {
        case .ok(let ok): return try ok.body.json.map { AccesDuParc(type, $0) }
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}

extension AccesDuParc {
    init(_ type: TypeAcces, _ acces: Components.Schemas.AccesAdminOut) {
        self.init(
            type: type, numero: acces.id, code: acces.code, porteurNom: acces.porteurNom,
            lotLibelle: acces.lotLibelle, perimetreCible: acces.perimetreCible ?? [], statut: acces.statut.rawValue,
            chezLocataire: acces.chezLocataire)
    }
}

extension ServiceSimule: ServiceBadgesCS {
    func parc(_ installation: Installation) async throws -> [AccesDuParc] {
        try await Task.sleep(for: .milliseconds(350))
        return Self.parcSimule
    }

    /// Un parc inventé : des porteurs qui n'appartiennent à personne.
    static let parcSimule: [AccesDuParc] = [
        AccesDuParc(
            type: .vigik, numero: 1, code: "4521", porteurNom: "Alix Exemple", lotLibelle: "Lot 12 — appartement",
            perimetreCible: ["Copropriété", "Bâtiment A"], statut: "actif", chezLocataire: false),
        AccesDuParc(
            type: .vigik, numero: 2, code: "417D5927", porteurNom: "Basile Fictif", lotLibelle: "Lot 21 — appartement",
            perimetreCible: ["Copropriété", "Bâtiment B"], statut: "perdu", chezLocataire: true),
        AccesDuParc(
            type: .telecommande, numero: 3, code: "TC-0042", porteurNom: "Alix Exemple",
            lotLibelle: "Lot 104 — parking", perimetreCible: ["Portail du parking"], statut: "actif",
            chezLocataire: false),
        AccesDuParc(
            type: .vigik, numero: 4, code: "7731", porteurNom: "Céleste Inventé", lotLibelle: nil,
            perimetreCible: [], statut: "suspendu", chezLocataire: false),
    ]
}
