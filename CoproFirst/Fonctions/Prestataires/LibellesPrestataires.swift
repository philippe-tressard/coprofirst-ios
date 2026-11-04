// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Une catégorie de prestataire : son code, son libellé, ce qu'elle couvre
/// (`TYPES_PRESTATAIRE`, générée dans `Genere/TablesPrestataires.swift`).
struct TypePrestataire: Hashable, Sendable {
    let code: String
    let libelle: String
    let description: String
}

/// Les libellés et la recherche de « Prestataires ».
///
/// ⚠️ Aucune RÈGLE du site n'est recopiée (`frequenceLabel`, retard d'une visite,
/// moyenne des avis, équipement d'un contrat, prochaine visite d'un prestataire —
/// `standards/09` §8) : l'écran montre la donnée brute ou rien, et coprofirst#2507
/// demande à l'API de les servir.
enum LibellesPrestataires {
    static func type(_ code: String?) -> String {
        guard let code else { return FormatsDuSite.tiret }
        return TablesPrestataires.types.first { $0.code == code }?.libelle ?? code
    }

    /// La recherche de la liste : tous les mots, dans n'importe quel ordre, sans
    /// accents ni casse, sur ce que la fiche affiche.
    static func correspond(_ prestataire: Prestataire, equipement: String, recherche: String) -> Bool {
        let mots = replier(recherche).split(whereSeparator: \.isWhitespace)
        guard !mots.isEmpty else { return true }
        let contacts = prestataire.contacts.flatMap { [$0.prenom, $0.nom, $0.fonction, $0.telephone, $0.email] }
        let fiche: [String?] = [
            prestataire.nom, equipement, type(prestataire.type), prestataire.telephone, prestataire.email,
            prestataire.adresse, prestataire.description.map(TexteDuSite.apercu),
        ]
        let texte = replier((fiche + contacts).compactMap { $0 }.joined(separator: " "))
        return mots.allSatisfy { texte.contains($0) }
    }

    static func replier(_ texte: String) -> String {
        texte.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
    }

    /// L'ordre d'une liste de contrats : la visite la plus proche d'abord, les
    /// contrats sans échéance à la fin (dates ISO : l'ordre des chaînes est celui des jours).
    static func parEcheance(_ a: Contrat, _ b: Contrat) -> Bool {
        switch (a.prochaineVisite, b.prochaineVisite) {
        case (let x?, let y?): x < y
        case (.some, nil): true
        default: false
        }
    }
}
