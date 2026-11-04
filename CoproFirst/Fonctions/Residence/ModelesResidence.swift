// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// La fiche de la résidence (GET /copropriete) — ce que l'onglet « Fiche » montre.
///
/// Les champs suivent `CoproprieteRead` : l'app n'y calcule rien que le serveur ne
/// serve. `assuranceReconduit` et `syndicEchu` sont SERVIS (le site les lit tels quels).
struct FicheResidence: Hashable, Sendable {
    var nom: String
    var adresse: String
    var photo: String?
    var immatriculation: String?
    var lotsPrincipaux: Int?
    var lotsTotal: Int?
    var parkingsCommuns: Int
    var assurance: String?
    var assuranceEcheance: Date?
    var assuranceReconduit: Bool
    var syndic: String?
    var syndicEcheance: Date?
    var syndicEchu: Bool
}

/// Un bâtiment et sa composition (GET /copropriete/batiments).
struct Batiment: Hashable, Sendable, Identifiable {
    let id: Int
    var numero: String
    var parkings: Int
    var caves: Int
    var appartements: Int
    var locauxCommerciaux: Int
}

/// Un document de la résidence (GET /documents?categorie=…) : plan, règlement, PV d'AG.
struct DocumentResidence: Hashable, Sendable, Identifiable {
    let id: Int
    var titre: String
    var description: String?
    var fichier: String
    var batimentId: Int?
    var annee: Int?
    /// La date que la rubrique montre : celle de l'acte (`date_document`) ou de l'AG
    /// (`date_ag`) — jamais celle du dépôt.
    var date: Date?
    /// Rattachements d'une annexe à sa fiche (`annexes_de`).
    var parent: Int?
    var regle: Int?
    var rapport: Int?
}

/// Une règle ou recommandation (GET /regles-residence, réponse non typée).
struct RegleResidence: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    var titre: String
    /// Du HTML de l'éditeur du site : il passe par `TexteDuSite`.
    var contenu: String?
}

/// Un diagnostic réglementaire et ses rapports (GET /diagnostics/types).
struct TypeDiagnostic: Hashable, Sendable, Identifiable {
    let id: Int
    var nom: String
    var texteLegislatif: String
    var frequence: String?
    var nonApplicable: Bool
    var rapports: [RapportDiagnostic]
}

struct RapportDiagnostic: Hashable, Sendable, Identifiable {
    let id: Int
    var titre: String
    var fichier: String
    var date: Date?
    /// Du HTML : il passe par `TexteDuSite`.
    var synthese: String?
}

/// Tout ce que la Fiche lit, en une vague — comme le site (`chargerFiche`).
struct ContenuFiche: Sendable {
    var fiche: FicheResidence
    var batiments: [Batiment]
    var regles: [RegleResidence]
    var plans: [DocumentResidence]
    var reglements: [DocumentResidence]
    var comptesRendus: [DocumentResidence]
    var diagnostics: [TypeDiagnostic]
    var annexes: [DocumentResidence]

    func annexes(deRegle id: Int) -> [DocumentResidence] { annexes.filter { $0.regle == id } }
    func annexes(deDocument id: Int) -> [DocumentResidence] { annexes.filter { $0.parent == id } }
    func annexes(deRapport id: Int) -> [DocumentResidence] { annexes.filter { $0.rapport == id } }

    /// « Bât. 2 » — la correspondance que le site fait (`batimentLabel`).
    func libelleBatiment(_ id: Int?) -> String {
        guard let id else { return TextesResidence.copropriete }
        return batiments.first { $0.id == id }.map { "Bât. \($0.numero)" } ?? "Bât. ?"
    }
}

/// Une entrée du carnet d'entretien (GET /carnet-entretien, réponse non typée).
struct EntreeCarnet: Codable, Hashable, Sendable, Identifiable {
    var date: String
    var libelle: String
    var origine: String
    var detail: String?
    var numero: String?
    var equipement: String?
    var lien: String?
    var alerte: String?
    /// Un extrait du texte de l'affaire, en HTML.
    var extrait: String?

    var id: String { "\(origine)-\(lien ?? libelle)-\(date)" }

    /// Le jour de l'entrée (le serveur sert une date ISO, `AAAA-MM-JJ`).
    var jour: Date? { Dates.jour(date) }
}

/// Le carnet tel que le serveur le sert : les entrées, dans son ordre.
struct Carnet: Codable, Hashable, Sendable {
    var entrees: [EntreeCarnet]
}

/// Le carnet et les libellés des équipements qui rangent ses entrées.
struct ContenuCarnet: Hashable, Sendable {
    var entrees: [EntreeCarnet]
    var libellesEquipements: [String: String]

    /// Les entrées rangées par équipement, dans l'ordre où le serveur les sert : un
    /// groupe prend la place de sa première entrée (la plus récente).
    var groupes: [(titre: String, entrees: [EntreeCarnet])] {
        var ordre: [String?] = []
        var parEquipement: [String?: [EntreeCarnet]] = [:]
        for entree in entrees {
            if parEquipement[entree.equipement] == nil { ordre.append(entree.equipement) }
            parEquipement[entree.equipement, default: []].append(entree)
        }
        return ordre.map { code in
            let titre = code.map { libellesEquipements[$0] ?? $0 } ?? TextesCarnet.sansEquipement
            return (titre, parEquipement[code] ?? [])
        }
    }

    var enAlerte: [EntreeCarnet] { entrees.filter { !($0.alerte ?? "").isEmpty } }
}

/// Un périmètre de la résidence (GET /perimetres) : le filtre du carnet.
struct Perimetre: Hashable, Sendable, Identifiable {
    let code: String
    var libelle: String
    var id: String { code }
}

/// L'état de l'assistant du règlement (GET /reglement).
struct EtatReglement: Hashable, Sendable {
    var disponible: Bool
    var texteDisponible: Bool
    var lienReglement: String?
}

/// Une question posée à l'assistant, et sa réponse (QuestionReglementRead).
struct QuestionReglement: Hashable, Sendable, Identifiable {
    let id: Int
    var question: String
    var reponse: String
    var verdictLibelle: String
    var poseeLe: Date
    var texteEnVigueur: Bool
    var selonReglement: String?
    var selonAG: String?
    var synthese: String?
    var reserves: String?
    var provenance: String?
    var modele: String?
    var auteur: String?
    var dansLaFAQ: Bool
    var extraits: [ExtraitReglement]

    var extraitsReglement: [ExtraitReglement] { extraits.filter { $0.source != "ag" } }
    var extraitsAG: [ExtraitReglement] { extraits.filter { $0.source == "ag" } }
    var verifies: Int { extraits.filter(\.verifie).count }
}

struct ExtraitReglement: Hashable, Sendable {
    var citation: String
    var verifie: Bool
    var reference: String?
    var apport: String?
    var acte: String?
    var page: String?
    var source: String?

    /// L'acte et la page, joints comme le site les joint (`ExtraitsReglement.svelte`),
    /// ou la référence donnée à défaut.
    var origine: String? {
        let morceaux = [acte, page].compactMap { $0 }.filter { !$0.isEmpty }
        return morceaux.isEmpty ? reference : morceaux.joined(separator: " — ")
    }
}

/// Les dates du serveur : `AAAA-MM-JJ` pour un jour, sur le calendrier de l'app.
enum Dates {
    static func jour(_ texte: String?) -> Date? {
        guard let texte else { return nil }
        // Lu à minuit sur le fuseau de l'appareil : le jour affiché reste celui servi.
        let format = Date.ISO8601FormatStyle(timeZone: .current).year().month().day()
        return try? Date(String(texte.prefix(10)), strategy: format)
    }
}
