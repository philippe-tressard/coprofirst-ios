// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que « Mes lots & accès » demande à une installation (#13). Réalisé par
/// `ServiceAPI` (client généré) et `ServiceSimule`, dans ce dossier — `Session/` ne
/// grossit pas (décision de coordination du 04/11/2026).
///
/// ⚠️ Aucune route n'est écrite ici : chacune est une opération du client généré.
/// Un geste n'est OFFERT qu'au rôle que la route accepte (`DroitsAcces`) ; le serveur
/// reste le seul juge, et un refus s'affiche avec sa phrase (`RefusDuServeur`, Commun/Session).
protocol ServiceAcces: Sendable {
    /// GET /lots/mes-lots : les lots du COMPTE, et seulement eux (jamais ceux d'un voisin).
    func mesLots(_ installation: Installation) async throws -> [LotDuCompte]
    /// GET /bailleur/mon-bail : le bail du locataire, `nil` sans bail.
    func monBail(_ installation: Installation) async throws -> BailDuLocataire?
    /// GET /bailleur/mes-baux (copropriétaire) ou /bailleur/tous-les-baux (conseil).
    func baux(_ installation: Installation, tous: Bool) async throws -> [Bail]
    /// GET /acces/mes-vigiks ou /acces/mes-telecommandes : ce que l'on détient.
    func mesAcces(_ type: TypeAcces, dans installation: Installation) async throws -> [AccesDetenu]
    /// GET /bailleur/mes-acces-recus : ce que le bailleur a confié au locataire.
    func accesRecus(_ installation: Installation) async throws -> [AccesDetenu]
    /// POST /acces/commandes : demander un accès pour un de SES lots.
    func demander(_ demande: DemandeAcces, dans installation: Installation) async throws
    /// POST /acces/declarer-badge : signaler un accès déjà détenu. Rend `import_resolu`.
    func declarer(_ type: TypeAcces, code: String, dans installation: Installation) async throws -> Bool
    /// PATCH /acces/{vigiks|telecommandes}/{id}/perdu.
    func signalerPerdu(_ acces: AccesDetenu, dans installation: Installation) async throws
    /// POST /bailleur/baux/{id}/recuperer-acces : reprendre ce qu'on a confié.
    func recupererAcces(bail: Int, dans installation: Installation) async throws
}

extension Parcours {
    /// Le service de « Mes lots & accès », s'il est réalisé (il l'est par les deux
    /// services de l'app : `ServiceAccesTests` le vérifie).
    var serviceAcces: (any ServiceAcces)? { service as? any ServiceAcces }
}

enum TypeAcces: String, CaseIterable, Sendable, Identifiable {
    case vigik, telecommande
    var id: String { rawValue }
    var libelle: String { LibellesAcces.typeAcces(rawValue) }
}

/// Un lot du compte (`LotRead`, lu dans `/lots/mes-lots`).
struct LotDuCompte: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    let numero: String
    var type: String?
    var typeAppartement: String?
    var etage: Int?
    var superficie: Double?
    var batimentNom: String?
    /// Mon lien au lot : `locataire` pour un lot que je LOUE.
    var typeLien: String?
    /// La porte ou la place, ce que le résident dit (« 5 & 6 »).
    var numeroUsage: String?
    var perimetres: [PerimetreDuLot]?
    var alertes: [ConstatDuLot]?

    var loue: Bool { typeLien == "locataire" }
    /// « Bât. A / 12 » — l'en-tête de la carte d'un lot sur le site.
    var intitule: String { "\(batimentNom ?? FormatsDuSite.tiret) / \(numero)" }

    func perimetres(_ relation: String) -> String? {
        let libelles = (perimetres ?? []).filter { $0.relation == relation }.map(\.libelle)
        return libelles.isEmpty ? nil : libelles.joined(separator: ", ")
    }
}

struct PerimetreDuLot: Codable, Hashable, Sendable {
    let libelle: String
    let relation: String
}

/// Ce que le propriétaire doit savoir de son lot (`ConstatPatrimoine`).
struct ConstatDuLot: Codable, Hashable, Sendable {
    let code: String
    let gravite: String
    let message: String
}

/// Un badge ou une télécommande (`AccesOut`).
struct AccesDetenu: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    let code: String
    var statut: String
    var type: String
    var chezLocataire: Bool?
    var bailId: Int?
}

/// Un bail (`BailOut`).
struct Bail: Hashable, Sendable, Identifiable {
    let id: Int
    let lotId: Int
    var statut: String
    var locataireId: Int?
    var locatairePrenom: String?
    var locataireNom: String?
    var locataireEmail: String?
    var locataireTelephone: String?
    var dateEntree: String
    var dateSortiePrevue: String?
    var dateSortieReelle: String?
    var notes: String?
    var objets: [ObjetRemis]

    /// `bailEnCours`, `front/src/lib/bail.ts`.
    var enCours: Bool { statut == "actif" || statut == "en_cours_sortie" }
    var termine: Bool { statut == "termine" }
    var nomLocataire: String { LibellesAcces.nom(locatairePrenom, locataireNom) }
    /// Le regroupement du site : un même locataire, ou ce bail seul (`ext_<id>`).
    var cleLocataire: String { locataireId.map { "\($0)" } ?? "ext_\(id)" }
}

/// Un objet remis au locataire (`ObjetOut`).
struct ObjetRemis: Hashable, Sendable, Identifiable {
    let id: Int
    var type: String
    var libelle: String
    var quantite: Int
    var reference: String?
    var statut: String
    var remisLe: String?
    var renduLe: String?
}

/// Le bail vu du locataire (`BailLocataireOut`).
struct BailDuLocataire: Hashable, Sendable {
    let id: Int
    var statut: String
    var lotBatimentNom: String?
    var lotNumero: String?
    var lotType: String?
    var lotTypeAppartement: String?
    var lotEtage: Int?
    var lotSuperficie: Double?
    var dateEntree: String
    var dateSortiePrevue: String?
    var bailleurPrenom: String
    var bailleurNom: String
    var bailleurEmail: String?
    var bailleurTelephone: String?
}

/// Une demande d'accès (`CommandeAccesCreate`).
struct DemandeAcces: Hashable, Sendable {
    var type: TypeAcces = .vigik
    var lotId: Int?
    var quantite = 1
    var motif = ""
}
