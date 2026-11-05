// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que l'onglet « Annuaire CS & Syndic » demande à une installation (#15) : la
/// composition du conseil et la fiche du syndic, à LIRE et à RÉÉCRIRE. Chaque
/// enregistrement envoie la liste ENTIÈRE (en-tête et membres), comme le site.
///
/// ⚠️ Les deux lectures ne sont pas typées dans le contrat (pas de `response_model`) :
/// relues en miroir (`Relecture`) en attendant que coprofirst les type.
protocol ServiceAnnuaireCS: Sendable {
    /// GET /admin/annuaire/cs.
    func conseil(_ installation: Installation) async throws -> ConseilCS
    /// PUT /admin/annuaire/cs.
    func enregistrer(_ conseil: ConseilCS, dans installation: Installation) async throws
    /// GET /admin/annuaire/syndic.
    func syndic(_ installation: Installation) async throws -> SyndicCS
    /// PUT /admin/annuaire/syndic.
    func enregistrer(_ syndic: SyndicCS, dans installation: Installation) async throws
}

extension ContexteOngletCS {
    var serviceAnnuaire: (any ServiceAnnuaireCS)? { service as? any ServiceAnnuaireCS }
}

/// Le conseil syndical : l'AG qui l'a élu, la communauté WhatsApp, ses membres.
struct ConseilCS: Codable, Hashable, Sendable {
    var agAnnee: Int?
    /// « 2026-06-12 », tel que le serveur le sert et le reçoit.
    var agDate: String?
    var whatsappUrl: String?
    var membres: [MembreConseil]
}

/// Un membre du conseil. `id` est nul tant que le serveur ne l'a pas enregistré.
struct MembreConseil: Codable, Hashable, Sendable {
    var id: Int?
    var genre: String?
    var prenom: String?
    var nom: String?
    var batimentId: Int?
    var batimentNom: String?
    var etage: Int?
    var estGestionnaireSite: Bool?
    var estPresident: Bool?
    var photoUrl: String?
    /// L'inscrit auquel la fiche est liée — conservé tel quel à chaque envoi.
    var userId: Int?
}

/// Le syndic : son nom (le contrat de syndic fait foi s'il en désigne un), son
/// adresse, son espace client, ses interlocuteurs dans l'ordre choisi.
struct SyndicCS: Codable, Hashable, Sendable {
    var nomSyndic: String?
    /// `contrat`, `saisie` ou `aucune` : d'où vient le nom affiché.
    var nomSyndicSource: String?
    var adresse: String?
    var siteWeb: String?
    var membres: [MembreSyndic]

    /// Le nom vient du contrat de syndic : il ne se saisit pas ici (`utils/syndic.py`).
    var nomDuContrat: Bool { nomSyndicSource == "contrat" }
}

/// Un interlocuteur du syndic.
struct MembreSyndic: Codable, Hashable, Sendable {
    var id: Int?
    var genre: String?
    var prenom: String?
    var nom: String?
    var fonction: String?
    var email: String?
    /// Un ou plusieurs numéros, séparés par des virgules — la forme du serveur.
    var telephone: String?
    var estPrincipal: Bool?
    var photoUrl: String?
    var userId: Int?
}

extension ServiceAPI: ServiceAnnuaireCS {
    func conseil(_ installation: Installation) async throws -> ConseilCS {
        let sortie = try await appeler { try await client(installation.adresse).getAdminAnnuaireCs() }
        switch sortie {
        case .ok(let ok): return try Relecture.lire(ConseilCS.self, depuis: try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func enregistrer(_ conseil: ConseilCS, dans installation: Installation) async throws {
        let corps = Components.Schemas.CompositionCSIn(
            agAnnee: conseil.agAnnee, agDate: conseil.agDate?.nulSiVide,
            membres: conseil.membres.map(Components.Schemas.MembreCSIn.init),
            whatsappUrl: conseil.whatsappUrl?.nulSiVide)
        let sortie = try await appeler {
            try await client(installation.adresse).putAdminAnnuaireCs(body: .json(corps))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func syndic(_ installation: Installation) async throws -> SyndicCS {
        let sortie = try await appeler { try await client(installation.adresse).getAdminAnnuaireSyndic() }
        switch sortie {
        case .ok(let ok): return try Relecture.lire(SyndicCS.self, depuis: try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func enregistrer(_ syndic: SyndicCS, dans installation: Installation) async throws {
        let corps = Components.Schemas.SyndicIn(
            adresse: syndic.adresse ?? "", membres: syndic.membres.map(Components.Schemas.MembreSyndicIn.init),
            nomSyndic: syndic.nomSyndic ?? "", siteWeb: syndic.siteWeb?.nulSiVide)
        let sortie = try await appeler {
            try await client(installation.adresse).putAdminAnnuaireSyndic(body: .json(corps))
        }
        switch sortie {
        case .ok: return
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }
}

extension Components.Schemas.MembreCSIn {
    init(_ membre: MembreConseil) {
        self.init(
            batimentId: membre.batimentId, estPresident: membre.estPresident ?? false, etage: membre.etage,
            genre: membre.genre ?? AnnuaireCS.civiliteParDefaut, id: membre.id, nom: membre.nom ?? "",
            prenom: membre.prenom ?? "", userId: membre.userId)
    }
}

extension Components.Schemas.MembreSyndicIn {
    init(_ membre: MembreSyndic) {
        self.init(
            email: membre.email?.nulSiVide, estPrincipal: membre.estPrincipal ?? false,
            fonction: membre.fonction?.nulSiVide, genre: membre.genre ?? AnnuaireCS.civiliteParDefaut, id: membre.id,
            nom: membre.nom ?? "", prenom: membre.prenom ?? "", telephone: membre.telephone?.nulSiVide,
            userId: membre.userId)
    }
}

/// Ce que l'annuaire du conseil partage entre ses écrans.
enum AnnuaireCS {
    /// La civilité d'une fiche neuve : la première du site (`CIVILITES`, généré).
    static var civiliteParDefaut: String { TablesEspaceCS.civilites.first ?? "" }

    /// Les numéros d'un interlocuteur, tels que la saisie les tient : un champ par
    /// numéro, au moins un.
    static func telephones(_ champ: String?) -> [String] {
        let numeros = (champ ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return numeros.isEmpty ? [""] : numeros
    }

    /// …et rendus à la forme du serveur.
    static func champTelephone(_ numeros: [String]) -> String? {
        numeros.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: ",").nulSiVide
    }
}
