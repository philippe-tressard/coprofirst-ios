// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// ⚠️ PROVISOIRE (#13) : les libellés et les règles de « Prestataires », recopiés du
/// site EN ATTENDANT d'être générés (tables) ou servis par l'API (règles en code).
/// Chaque entrée nomme sa source dans coprofirst ; rien ne se recopie ailleurs.
/// Une catégorie de prestataire : son code, son libellé, ce qu'elle couvre.
struct TypePrestataire: Hashable, Sendable {
    let code: String
    let libelle: String
    let description: String
}

enum LibellesPrestataires {
    // MARK: Onglets — `pages.ts`, page `prestataires`

    static let onglets: [(id: String, libelle: String)] = [
        ("prestataires", "Prestataires"),
        ("contrats", "Contrats"),
        ("consommations", "Consommations"),
    ]

    static let descriptifs: [String: String] = [
        "prestataires": "Intervenants et contrats d'entretien de la résidence.",
        "contrats": "Contrats d'entretien en cours, leur échéance et leurs documents.",
        "consommations": "Suivi des relevés de compteurs et abonnements de la résidence.",
    ]

    // MARK: Tables — à générer

    /// `TYPES_PRESTATAIRE`, `front/src/lib/prestataires.ts` : libellé et description.
    static let types: [TypePrestataire] = [
        .init(
            code: "maintenance_depannage", libelle: "🔧 Maintenance & dépannage", description: "Entretien, réparations"),
        .init(code: "travaux", libelle: "🏗️ Travaux", description: "Interventions importantes"),
        .init(code: "reglementaire", libelle: "📋 Réglementaire", description: "Contrôles obligatoires"),
        .init(code: "etudes_expertise", libelle: "📐 Études & expertise", description: "Diagnostics, maîtrise d’œuvre"),
        .init(code: "gestion", libelle: "🏢 Gestion", description: "Syndic, gestion locative"),
    ]

    /// `FILTRES_CONTRAT`, `front/src/lib/prestataires.ts`.
    static let filtresContrat: [(code: String, libelle: String)] = [
        ("sous_contrat", "📄 Sous contrat"),
        ("sans_contrat", "Sans contrat"),
    ]

    static func type(_ code: String?) -> String {
        guard let code else { return FormatsDuSite.tiret }
        return types.first { $0.code == code }?.libelle ?? code
    }

    // MARK: Règles en code — à servir par l'API (coprofirst#2507)

    /// `frequenceLabel`, `front/src/lib/prestataires.ts`.
    static func frequence(_ type: String?, _ valeur: Int?) -> String {
        let n = valeur ?? 0
        switch type {
        case "semaines": return "↺ \(n) sem."
        case "mois": return "↺ Mensuel"
        case "fois_par_an": return "↺ \(n)×/an"
        case "ans": return "↺ tous les \(n) an(s)"
        default: return ""
        }
    }

    /// `moyenneNotes`, `front/src/lib/notations.ts` : arrondie au dixième, écrite
    /// telle que le site l'écrit (« 4.5 », point décimal).
    static func moyenne(_ notes: [Int]) -> String? {
        guard !notes.isEmpty else { return nil }
        let m = (Double(notes.reduce(0, +)) / Double(notes.count) * 10).rounded() / 10
        return m == m.rounded() ? String(Int(m)) : String(m)
    }

    /// `etoiles`, `front/src/lib/notations.ts`.
    static func etoiles(_ note: Double) -> String {
        let pleines = min(5, max(0, Int(note.rounded())))
        return String(repeating: "★", count: pleines) + String(repeating: "☆", count: 5 - pleines)
    }

    /// Une visite en retard : avant minuit, heure de l'appareil (`minuitDuJour`).
    static func enRetard(_ prochaineVisite: String?, aujourdhui: Date = .now) -> Bool {
        guard let jour = FormatsDuSite.jourLocal(prochaineVisite) else { return false }
        return jour < Calendar.current.startOfDay(for: aujourdhui)
    }

    /// `typeEquipementDuContrat`, `front/src/lib/reporting.ts`.
    static func equipementDuContrat(_ contrat: Contrat, prestataires: [Prestataire]) -> String {
        if !contrat.typeEquipement.isEmpty, contrat.typeEquipement != "autre" { return contrat.typeEquipement }
        if let specialite = prestataires.first(where: { $0.id == contrat.prestataireId })?.specialite,
            !specialite.isEmpty
        {
            return specialite
        }
        return contrat.typeEquipement.isEmpty ? "autre" : contrat.typeEquipement
    }

    /// `parEcheance` : la visite la plus proche d'abord, les contrats sans échéance à la fin.
    static func parEcheance(_ a: Contrat, _ b: Contrat) -> Bool {
        switch (a.prochaineVisite, b.prochaineVisite) {
        case (let x?, let y?): x < y
        case (.some, nil): true
        default: false
        }
    }

    /// La recherche du site (`filtrerPrestataires`) : tous les mots, dans n'importe
    /// quel ordre, sans accents ni casse.
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
}
