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
    /// Le code du parent ; `nil` pour une racine.
    var parent: String?
    /// Combien de niveaux ce nœud peut encore porter sous lui (`niveaux_libres`, contrat
    /// 1.17.0, #88) ; `nil` d'une installation antérieure, qui ne le sert pas.
    var niveauxLibres: Int?

    var id: String { code }

    init(
        code: String, libelle: String, profondeur: Int = 0, selectionnable: Bool = true, parDefaut: Bool = false,
        parent: String? = nil, niveauxLibres: Int? = nil
    ) {
        self.code = code
        self.libelle = libelle
        self.profondeur = profondeur
        self.selectionnable = selectionnable
        self.parDefaut = parDefaut
        self.parent = parent
        self.niveauxLibres = niveauxLibres
    }

    init(lu: Components.Schemas.PerimetreRead) {
        self.init(
            code: lu.code, libelle: lu.libelle, profondeur: lu.profondeur, selectionnable: lu.selectionnable,
            parDefaut: lu.parDefaut ?? false, parent: lu.parent)
    }

    /// L'arbre servi, ACTIFS seulement : le type généré, puis ce que le corps sert
    /// au-dessus du plancher — le MÊME branchement pour le service réel et l'API simulée.
    static func lus(_ generes: [Components.Schemas.PerimetreRead], corps: Data?) -> [Perimetre] {
        let auDessus = Relecture.auDessusDuPlancher(parLigne: PerimetreAuDessusDuPlancher.self, corps: corps)
        return generes.filter(\.actif).map { lu in
            var perimetre = Perimetre(lu: lu)
            perimetre.niveauxLibres = auDessus[lu.code]?.niveauxLibres
            return perimetre
        }
    }

    /// Les lieux qu'un sélecteur propose (#88) : les nœuds sélectionnables, jusqu'au
    /// niveau 3 et jamais plus bas — un nœud écrit avant la règle sous un parent qui ne
    /// peut plus rien porter (`niveaux_libres` servi à 0) ne se propose pas. Le plafond
    /// n'est pas recopié ici : il se lit sur ce que le serveur sert. Une installation
    /// antérieure au contrat 1.17.0 ne le sert pas : tout nœud sélectionnable, comme avant.
    static func aSaisir(_ perimetres: [Perimetre]) -> [Perimetre] {
        let libres = Dictionary(
            perimetres.map { ($0.code, $0.niveauxLibres) }, uniquingKeysWith: { premier, _ in premier })
        return perimetres.filter { perimetre in
            let place = perimetre.parent.flatMap { libres[$0] ?? nil }
            return perimetre.selectionnable && (place ?? 1) > 0
        }
    }

    /// Le code du périmètre que le serveur désigne par défaut, s'il en désigne un.
    static func codeParDefaut(_ perimetres: [Perimetre]) -> String? { perimetres.first(where: \.parDefaut)?.code }

    /// Les libellés de `codes` (`perimetre_cible`), lus dans l'arbre servi : le périmètre
    /// par défaut se TAIT (`BadgePerimetre` du site), et un code que l'arbre ne connaît pas
    /// (nœud retiré, arbre pas encore lu) ne s'affiche jamais brut (« bat:2 »).
    static func libelles(_ codes: [String], parmi perimetres: [Perimetre]) -> [String] {
        codes.compactMap { code in
            perimetres.first { $0.code == code }.flatMap { $0.parDefaut ? nil : $0.libelle }
        }
    }
}

/// Ce que GET /perimetres sert au-dessus du plancher (contrat 1.17.0, #88), relu par
/// `Relecture.auDessusDuPlancher` : `niveau` et `hauteur` ne servent pas à l'app.
struct PerimetreAuDessusDuPlancher: Decodable, Identifiable {
    let code: String
    var niveauxLibres: Int?
    var id: String { code }
}

/// GET /perimetres : les périmètres ACTIFS, dans l'ordre de l'arbre servi. Les menus
/// qui en ont besoin en héritent (`ServiceResidence`, `ServiceAffaires`) : une seule
/// lecture, un seul type de retour.
protocol ServicePerimetres: Sendable {
    func perimetres(_ installation: Installation) async throws -> [Perimetre]
}

extension ServiceAPI: ServicePerimetres {
    func perimetres(_ installation: Installation) async throws -> [Perimetre] {
        let (sortie, corps) = try await appeler {
            try await CorpsServi.garder { try await client(installation.adresse).getPerimetres() }
        }
        switch sortie {
        case .ok(let ok): return Perimetre.lus(try ok.body.json, corps: corps)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}

extension ServiceSimule: ServicePerimetres {
    func perimetres(_ installation: Installation) async throws -> [Perimetre] { try FixturesPerimetres.lus() }
}
