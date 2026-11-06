// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Qui regarde la Communauté (GET /auth/me) : ce qui ouvre les onglets et les gestes.
struct MoiCommunaute: Hashable, Sendable {
    let id: Int
    let statut: String
    let roles: [String]
    /// La CONCLUSION du serveur (`motif_de_refus`, `utils/communaute.py`) : rempli
    /// quand la Communauté est fermée à ce compte — profil de gestionnaire (l'Avis
    /// reste ouvert) ou suspension (tout est fermé). L'app ne recalcule pas la règle.
    let motifRefus: String?

    var estConseil: Bool { roles.contains("conseil_syndical") || estAdmin }
    var estAdmin: Bool { roles.contains("admin") }
    /// Ce que le compte est, pour juger des onglets — la règle GÉNÉRÉE du site.
    var droits: DroitsOnglet { DroitsOnglet(roles: roles, role: nil, statut: statut) }
}

/// Les rubriques de la page `communaute`. Leurs identifiants sont ceux du site ;
/// libellés et réserves viennent de la table GÉNÉRÉE (`OngletsDuSite`, #30).
enum OngletCommunaute: String, CaseIterable, Identifiable {
    case sondages, idees, annonces, avis

    static let page = "communaute"
    var id: String { rawValue }

    /// Le libellé du site ; l'identifiant à défaut, pour qu'un manque se voie.
    var libelle: String {
        OngletsDuSite.parPage[Self.page]?.first { $0.id == rawValue }?.libelle ?? rawValue
    }

    /// Les rubriques qu'un compte ouvre, dans l'ordre du site (`ongletsOuverts`).
    static func ouverts(_ droits: DroitsOnglet) -> [OngletCommunaute] {
        OngletsDuSite.ouverts(page: page, droits: droits).compactMap { OngletCommunaute(rawValue: $0.id) }
    }
}

/// Un sondage de la liste (`SondageRead`, typé dans le contrat).
struct SondageResume: Hashable, Sendable, Identifiable {
    let id: Int
    let question: String
    let description: String?
    let clotureLe: Date?
    let cloture: Bool
    let nbVotants: Int
    let archivee: Bool
    let creeLe: Date
}

/// Une réponse du fil d'une idée ou d'une annonce. Texte brut, jamais du HTML.
struct ReponseCommunaute: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    let auteurId: Int?
    let contenu: String
    let creeLe: Date
    let auteurNom: String?
    let auteurBatiment: String?
    let auteurRole: String?
    let estCs: Bool?
}

/// Une idée (GET /idees — réponse non typée dans le contrat, relue ici).
struct Idee: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    let titre: String
    let description: String
    let auteurId: Int?
    let statut: String
    let creeLe: Date
    var nbVotes: Int
    var monVote: Bool
    let archivee: Bool?
    var reponses: [ReponseCommunaute]?
}

/// Une petite annonce (GET /annonces — non typée dans le contrat, relue ici).
struct Annonce: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    let titre: String
    let description: String
    let typeAnnonce: String
    let categorie: String
    let prix: Double?
    let negotiable: Bool?
    let photos: [String]?
    var statut: String
    let auteurPrenom: String?
    let auteurNom: String?
    /// Absent quand l'auteur masque ses coordonnées.
    let auteurEmail: String?
    let estAuteur: Bool?
    let archivee: Bool?
    let creeLe: Date
    var reponses: [ReponseCommunaute]?
}

/// Un avis sur l'application (`AvisRead`, typé dans le contrat).
struct AvisResident: Hashable, Sendable, Identifiable {
    let id: Int
    let note: Int
    let titre: String
    let description: String
    let auteurNom: String?
    let auteurRole: String?
    let estAuteur: Bool
    let reponse: String?
    let reponseLe: Date?
    let remarque: String?
    let consentement: Bool?
    var archivee: Bool
    let restaurable: Bool
    let luDeTous: Bool
    let retenu: Bool
    let creeLe: Date
}

/// GET /avis : les avis, et ce que le serveur dit de celui qui regarde.
struct ListeAvis: Hashable, Sendable {
    var avis: [AvisResident]
    /// Celui qui GÈRE le site (réponses, export) — servi par l'API.
    let gestionnaire: Bool
    let monAvisId: Int?
}

/// Ce qu'on saisit pour une annonce (POST /annonces).
struct SaisieAnnonce: Hashable, Sendable {
    var titre = ""
    var description = ""
    var type = "vente"
    var categorie = "divers"
    var prix: Double?
    var negociable = false
    var coordonneesVisibles = true
}

/// Ce qu'on saisit pour un avis (POST /avis, PATCH /avis/{id}).
struct SaisieAvis: Hashable, Sendable {
    var note = 0
    var titre = ""
    var description = ""
    var remarque = ""
    var consentement: Bool?
}

/// Le fil où l'on répond, et le contenu qu'on signale.
enum CibleCommunaute: Hashable, Sendable {
    case idee(Int)
    case annonce(Int)
    case reponse(Int)

    /// `cible_type` de POST /signalements.
    var typeSignalement: String {
        switch self {
        case .idee: "idee"
        case .annonce: "annonce"
        case .reponse: "reponse"
        }
    }

    var id: Int {
        switch self {
        case .idee(let id), .annonce(let id), .reponse(let id): id
        }
    }
}

/// Un statut : son code, son libellé, sa pastille `badge-*`.
struct EntreeStatut {
    let code: String
    let libelle: String
    let pastille: String
}

/// Les règles de la Communauté que le contrat ne sert pas — tables GÉNÉRÉES
/// (`Genere/TablesCommunaute.swift`, `scripts/generer.py`).
enum RegleCommunaute {
    static let noteRemarque = TablesCommunaute.noteRemarque
    static let notePubliable = TablesCommunaute.notePubliable
    static let statutsIdee = TablesCommunaute.statutsIdee
    static let typesAnnonce = TablesCommunaute.typesAnnonce
    static let categoriesAnnonce = TablesCommunaute.categoriesAnnonce
    static let trisAnnonce = TablesCommunaute.trisAnnonce
    static let statutsAnnonce = TablesCommunaute.statutsAnnonce

    /// Sous le seuil du serveur, l'avis dit ce qui a manqué.
    static func demandeRemarque(_ note: Int) -> Bool { (TablesCommunaute.noteMin..<noteRemarque).contains(note) }
    /// À partir de l'autre seuil, l'auteur dit s'il accepte la diffusion.
    static func demandeConsentement(_ note: Int) -> Bool { note >= notePubliable }
    /// Une note valable pour le serveur.
    static func noteValable(_ note: Int) -> Bool {
        (TablesCommunaute.noteMin...TablesCommunaute.noteMax).contains(note)
    }

    /// Un code inconnu se lit tel quel, en gris : un libellé manquant doit se voir.
    static func libelle(_ code: String, dans table: [(code: String, libelle: String)]) -> String {
        table.first { $0.code == code }?.libelle ?? code
    }
}
