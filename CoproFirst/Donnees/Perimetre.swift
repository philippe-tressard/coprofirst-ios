// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Un périmètre de la copropriété (`PerimetreRead`, GET /perimetres) : le filtre du
/// carnet (Ma résidence), le lieu d'une affaire (Mes affaires) — un seul modèle (#41).
///
/// Le périmètre PAR DÉFAUT (« toute la copropriété ») est celui que le serveur désigne
/// (`par_defaut`, coprofirst#2514, #54) : l'app ne refait pas le tri des racines.
struct Perimetre: Identifiable, Hashable, Sendable {
    let code: String
    var libelle: String
    /// Le rang dans l'arbre (0 : une racine) — le retrait d'une ligne du choix.
    var profondeur: Int
    /// Proposable comme lieu d'un contenu (un nœud de regroupement ne l'est pas).
    var selectionnable: Bool
    /// Le défaut du serveur : un seul nœud au plus, aucun sur un arbre vide.
    var parDefaut: Bool

    var id: String { code }

    init(code: String, libelle: String, profondeur: Int = 0, selectionnable: Bool = true, parDefaut: Bool = false) {
        self.code = code
        self.libelle = libelle
        self.profondeur = profondeur
        self.selectionnable = selectionnable
        self.parDefaut = parDefaut
    }

    init(lu: Components.Schemas.PerimetreRead) {
        self.init(
            code: lu.code, libelle: lu.libelle, profondeur: lu.profondeur, selectionnable: lu.selectionnable,
            parDefaut: lu.parDefaut ?? false)
    }

    /// Le code du périmètre que le serveur désigne par défaut, s'il en désigne un.
    static func codeParDefaut(_ perimetres: [Perimetre]) -> String? { perimetres.first(where: \.parDefaut)?.code }
}

/// GET /perimetres : les périmètres ACTIFS, dans l'ordre de l'arbre servi. Les menus
/// qui en ont besoin en héritent (`ServiceResidence`, `ServiceAffaires`) : une seule
/// lecture, un seul type de retour.
protocol ServicePerimetres: Sendable {
    func perimetres(_ installation: Installation) async throws -> [Perimetre]
}

extension ServiceAPI: ServicePerimetres {
    func perimetres(_ installation: Installation) async throws -> [Perimetre] {
        let sortie = try await appeler { try await client(installation.adresse).getPerimetres() }
        switch sortie {
        case .ok(let ok): return try ok.body.json.filter(\.actif).map(Perimetre.init(lu:))
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}

extension ServiceSimule: ServicePerimetres {
    func perimetres(_ installation: Installation) async throws -> [Perimetre] { Self.perimetres }

    /// L'arbre inventé : une racine, quatre lieux ; le carnet filtre sur `bat_a`.
    static let perimetres: [Perimetre] = [
        Perimetre(code: "copropriete", libelle: "Toute la copropriété", parDefaut: true),
        Perimetre(code: "bat_a", libelle: "Bâtiment A", profondeur: 1),
        Perimetre(code: "bat_b", libelle: "Bâtiment B", profondeur: 1),
        Perimetre(code: "parking", libelle: "Parking", profondeur: 1),
        Perimetre(code: "jardin", libelle: "Jardin", profondeur: 1),
    ]
}
