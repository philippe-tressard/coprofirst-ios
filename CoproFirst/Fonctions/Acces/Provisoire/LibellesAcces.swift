// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// ⚠️ PROVISOIRE (#13) : les libellés de « Mes lots & accès », recopiés du site EN
/// ATTENDANT qu'ils soient générés (tables) ou servis par l'API (règles en code).
///
/// Chaque entrée nomme sa source dans coprofirst (`front/src/lib/…`). Rien de ce
/// fichier ne se recopie ailleurs dans l'app : il disparaît d'un bloc quand
/// `Charte/OngletsDuSite.swift` et les tables générées arrivent (coordination,
/// 04/11/2026), et quand coprofirst sert les libellés des règles (coprofirst#2507).
enum LibellesAcces {
    // MARK: Onglets — `pages.ts`, page `mon-lot` (libellés sans pictogramme, comme
    // `Parite/ONGLETS-DU-SITE.md` les génère).

    static let onglets: [(id: String, libelle: String)] = [
        ("lots", "Mes lots"),
        ("badges", "Mes badges d’accès (Vigik)"),
        ("telecommandes", "Télécommandes de parking"),
        ("location", "Gestion locative"),
    ]

    /// Le descriptif de chaque onglet (`descriptif`, HTML de `pages.ts`).
    ///
    /// ⚠️ Ceux des deux onglets d'accès ne sont PAS repris : ils décrivent la page
    /// web (« bouton … en haut à droite », un lien de la FAQ) et égareraient dans
    /// l'app, où les gestes sont dans le menu « + ».
    static let descriptifs: [String: String] = [
        "lots": "Situation de vos lots dans la résidence : appartements, caves et parkings.",
        "location": "Suivi de vos baux, locataires et documents de gestion locative.",
    ]

    // MARK: Tables — à générer

    /// `STATUTS_ACCES`, `front/src/lib/types-acces.ts`.
    static let statutsAcces: [String: LibelleTeinte] = [
        "actif": .init("Actif", "badge-green"),
        "suspendu": .init("Suspendu", "badge-orange"),
        "perdu": .init("Perdu", "badge-red"),
    ]

    /// `TYPES_ACCES`, `front/src/lib/types-acces.ts`.
    static let typesAcces: [(code: String, libelle: String)] = [
        ("vigik", "🏷️ Badge Vigik"),
        ("telecommande", "📡 Télécommande parking"),
    ]

    /// Le statut d'un bail, `front/src/lib/bail.ts` (rendu par `BadgeStatutBail`).
    static let statutsBail: [String: LibelleTeinte] = [
        "actif": .init("Actif", "badge-green"),
        "en_cours_sortie": .init("En cours de sortie", "badge-yellow"),
        "termine": .init("Terminé", "badge-gray"),
    ]

    /// Le type d'un objet remis, `components/InventaireBail.svelte`.
    static let typesObjet: [String: String] = [
        "cle": "🔑 Clé", "telecommande": "📡 Télécommande", "vigik": "🏷️ Vigik", "autre": "📦 Autre",
    ]

    /// Le statut d'un objet remis, `components/InventaireBail.svelte`.
    static let statutsObjet: [String: LibelleTeinte] = [
        "en_possession": .init("En possession", "badge-green"),
        "rendu": .init("Rendu", "badge-blue"),
        "perdu": .init("Perdu", "badge-red"),
        "non_remis": .init("Non remis", "badge-gray"),
    ]

    /// La gravité d'un constat sur un lot, `components/ConstatsLots.svelte`, dans
    /// l'ordre où le site les range (du plus grave au moins grave).
    static let gravites: [(code: String, teinte: LibelleTeinte)] = [
        ("bloquant", .init("Bloquant", "badge-red")),
        ("inconnu", .init("Inconnu", "badge-gray")),
        ("avertissement", .init("À savoir", "badge-orange")),
        ("information", .init("Information", "badge-blue")),
    ]

    static func statutAcces(_ code: String) -> LibelleTeinte { statutsAcces[code] ?? .brut(code) }
    static func statutBail(_ code: String) -> LibelleTeinte { statutsBail[code] ?? .brut(code) }
    static func statutObjet(_ code: String) -> LibelleTeinte { statutsObjet[code] ?? .brut(code) }
    static func typeAcces(_ code: String) -> String { typesAcces.first { $0.code == code }?.libelle ?? code }

    // MARK: Règles en code — à servir par l'API (coprofirst#2507)

    /// `lotTypeLabel`, `front/src/lib/utils.ts`.
    static func typeDeLot(_ type: String?) -> String {
        guard let type, !type.isEmpty else { return FormatsDuSite.tiret }
        switch type {
        case "appartement": return "Appartement"
        case "parking": return "Parking"
        case "cave": return "Cave"
        default:
            let lisible = type.replacingOccurrences(of: "_", with: " ")
            return lisible.prefix(1).uppercased() + lisible.dropFirst()
        }
    }

    /// `lotTypeComplet`, `front/src/lib/utils.ts` (demi-cadratin).
    static func typeComplet(_ type: String?, _ typeAppartement: String?) -> String {
        guard let typeAppartement, !typeAppartement.isEmpty else { return typeDeLot(type) }
        return "\(typeDeLot(type)) – \(typeAppartement)"
    }

    /// `etageLabel`, `front/src/lib/utils.ts`.
    static func etage(_ etage: Int?, suffixe: Bool = false) -> String {
        guard let etage else { return "" }
        if etage == 0 { return "RDC" }
        if etage < 0 { return "SS \(-etage)" }
        let rang = etage == 1 ? "1er" : "\(etage)ème"
        return suffixe ? "\(rang) étage" : rang
    }

    /// `nomAffiche`, `front/src/lib/noms.ts` : « Marie DURAND ».
    static func nomAffiche(_ prenom: String?, _ nom: String?) -> String {
        [prenom?.trimmingCharacters(in: .whitespaces), nom?.trimmingCharacters(in: .whitespaces).uppercased()]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// `nomLocataire`, `front/src/lib/bail.ts`.
    static func nomLocataire(_ prenom: String?, _ nom: String?) -> String {
        let nom = nomAffiche(prenom, nom)
        return nom.isEmpty ? "Locataire non renseigné" : nom
    }
}
