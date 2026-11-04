// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Un onglet d'une page du site : son identifiant, son libellé, son descriptif
/// (`pages.ts`, lu par `scripts/generer-acces-prestataires.py`).
struct OngletDuSite: Hashable, Sendable {
    let id: String
    let libelle: String
    let descriptif: String
}

/// Les libellés de « Mes lots & accès » : ceux des tables GÉNÉRÉES (`Genere/`), et
/// ceux que le site écrit dans un composant (`Provisoire/`).
///
/// ⚠️ Aucune RÈGLE du site n'est recopiée ici (`lotTypeLabel`, `etageLabel`,
/// `nomAffiche`…, `standards/09` §8) : l'écran montre la donnée brute, lisible, et
/// coprofirst#2507 demande à l'API de servir les libellés calculés.
enum LibellesAcces {
    static func statutAcces(_ code: String) -> LibelleTeinte { TablesAcces.statutsAcces[code] ?? .brut(code) }
    static func statutBail(_ code: String) -> LibelleTeinte { TablesAcces.statutsBail[code] ?? .brut(code) }
    static func statutObjet(_ code: String) -> LibelleTeinte {
        TablesDesComposants.statutsObjet[code] ?? .brut(code)
    }

    static func typeAcces(_ code: String) -> String {
        TablesAcces.typesAcces.first { $0.code == code }?.libelle ?? code
    }

    /// Un nom tel que l'API le sert, prénom puis nom ; « — » s'il n'y en a pas.
    static func nom(_ prenom: String?, _ nom: String?) -> String {
        let morceaux = [prenom, nom].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return morceaux.isEmpty ? FormatsDuSite.tiret : morceaux.joined(separator: " ")
    }
}

extension LotDuCompte {
    /// Le type tel que l'API le sert (« appartement T3 ») — `lotTypeLabel` n'est pas
    /// recopié (coprofirst#2507).
    var typeLu: String {
        let morceaux = [type, typeAppartement].compactMap { $0 }.filter { !$0.isEmpty }
        return morceaux.isEmpty ? FormatsDuSite.tiret : morceaux.joined(separator: " ")
    }
}
