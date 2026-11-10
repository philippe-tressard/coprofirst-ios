// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que l'onglet « Annuaire CS & Syndic » demande à une installation (#15) : la
/// composition du conseil et la fiche du syndic, à LIRE et à RÉÉCRIRE. Chaque
/// enregistrement envoie la liste ENTIÈRE (en-tête et membres), comme le site, et rend
/// la composition ENREGISTRÉE — ce que l'écran montre ensuite (#55).
protocol ServiceAnnuaireCS: Sendable {
    /// GET /admin/annuaire/cs.
    func conseil(_ installation: Installation) async throws -> ConseilCS
    /// PUT /admin/annuaire/cs : le conseil tel que le serveur l'a retenu.
    func enregistrer(_ conseil: ConseilCS, dans installation: Installation) async throws -> ConseilCS
    /// GET /admin/annuaire/syndic.
    func syndic(_ installation: Installation) async throws -> SyndicCS
    /// PUT /admin/annuaire/syndic : le syndic tel que le serveur l'a retenu.
    func enregistrer(_ syndic: SyndicCS, dans installation: Installation) async throws -> SyndicCS
    /// GET /admin/annuaire/rapprochement : ce qu'un nom saisi désigne — l'inscrit de même
    /// nom et, s'il faut le `localiser` (conseil), son logement. La règle est au serveur :
    /// le `PUT` l'applique de toute façon, l'écran la DEMANDE pour la montrer à la frappe.
    func rapprochement(nom: String, localiser: Bool, dans installation: Installation) async throws -> Rapprochement
}

extension ContexteOnglet {
    var serviceAnnuaire: (any ServiceAnnuaireCS)? { service as? any ServiceAnnuaireCS }
}

/// Le conseil syndical : l'AG qui l'a élu, la communauté WhatsApp, ses membres.
struct ConseilCS: Hashable, Sendable {
    var agAnnee: Int?
    /// « 2026-06-12 », tel que le serveur le sert et le reçoit.
    var agDate: String?
    var whatsappUrl: String?
    var membres: [MembreConseil]
}

/// Un membre du conseil. `id` est nul tant que le serveur ne l'a pas enregistré.
struct MembreConseil: Hashable, Sendable {
    var id: Int?
    var genre: String?
    var prenom: String?
    var nom: String?
    var batimentId: Int?
    var batimentNom: String?
    var etage: Int?
    /// L'étage tel que le serveur le dit (`etage_libelle`) — l'app ne le compose pas.
    var etageLibelle: String?
    var estGestionnaireSite: Bool?
    var estPresident: Bool?
    var photoUrl: String?
    /// L'inscrit auquel la fiche est liée — conservé tel quel à chaque envoi.
    var userId: Int?
}

/// Le syndic : son nom (le contrat de syndic fait foi s'il en désigne un), son
/// adresse, son espace client, ses interlocuteurs dans l'ordre choisi.
struct SyndicCS: Hashable, Sendable {
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
struct MembreSyndic: Hashable, Sendable {
    var id: Int?
    var genre: String?
    var prenom: String?
    var nom: String?
    var fonction: String?
    var email: String?
    /// Un ou plusieurs numéros, séparés par des virgules — la forme que le serveur REÇOIT.
    var telephone: String?
    /// Les numéros, un par un, tels que le serveur les SERT (`telephones`) : la saisie en
    /// part, l'app ne découpe pas `telephone` elle-même.
    var telephones: [String] = []
    var estPrincipal: Bool?
    var photoUrl: String?
    var userId: Int?
}

/// Ce qu'un nom saisi désigne (`Rapprochement`) : l'inscrit actif de même nom et, pour
/// le conseil, son logement d'après le registre importé.
struct Rapprochement: Hashable, Sendable {
    var userId: Int?
    var batimentId: Int?
    /// Le NUMÉRO du bâtiment (« A »).
    var batimentNom: String?
    var etage: Int?
}

extension ServiceAPI: ServiceAnnuaireCS {
    func conseil(_ installation: Installation) async throws -> ConseilCS {
        let sortie = try await appeler { try await client(installation.adresse).getAdminAnnuaireCs() }
        switch sortie {
        case .ok(let ok): return ConseilCS(try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func enregistrer(_ conseil: ConseilCS, dans installation: Installation) async throws -> ConseilCS {
        let corps = Components.Schemas.CompositionCSIn(
            agAnnee: conseil.agAnnee, agDate: conseil.agDate?.nulSiVide,
            membres: conseil.membres.map(Components.Schemas.MembreCSIn.init),
            whatsappUrl: conseil.whatsappUrl?.nulSiVide)
        let sortie = try await appeler {
            try await client(installation.adresse).putAdminAnnuaireCs(body: .json(corps))
        }
        switch sortie {
        case .ok(let ok): return ConseilCS(try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func syndic(_ installation: Installation) async throws -> SyndicCS {
        let sortie = try await appeler { try await client(installation.adresse).getAdminAnnuaireSyndic() }
        switch sortie {
        case .ok(let ok): return SyndicCS(try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func enregistrer(_ syndic: SyndicCS, dans installation: Installation) async throws -> SyndicCS {
        let corps = Components.Schemas.SyndicIn(
            adresse: syndic.adresse ?? "", membres: syndic.membres.map(Components.Schemas.MembreSyndicIn.init),
            nomSyndic: syndic.nomSyndic ?? "", siteWeb: syndic.siteWeb?.nulSiVide)
        let sortie = try await appeler {
            try await client(installation.adresse).putAdminAnnuaireSyndic(body: .json(corps))
        }
        switch sortie {
        case .ok(let ok): return SyndicCS(try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func rapprochement(nom: String, localiser: Bool, dans installation: Installation) async throws -> Rapprochement {
        let sortie = try await appeler {
            try await client(installation.adresse).getAdminAnnuaireRapprochement(
                query: .init(nom: nom, localiser: localiser))
        }
        switch sortie {
        case .ok(let ok): return Rapprochement(try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
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

    /// Les champs de saisie des numéros : ceux que le serveur sert, un champ vide au moins.
    static func champsTelephone(_ servis: [String]) -> [String] { servis.isEmpty ? [""] : servis }

    /// …et rendus à la forme du serveur.
    static func champTelephone(_ numeros: [String]) -> String? {
        numeros.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: ",").nulSiVide
    }
}

// MARK: - Lus par les types générés (contrat 1.12.0, coprofirst#2522)

extension ConseilCS {
    init(_ lu: Components.Schemas.CompositionConseil) { self.init(lu.agAnnee, lu.agDate, lu.whatsappUrl, lu.membres) }
    /// La composition ENREGISTRÉE que rend le `PUT` : la même forme que la lecture.
    init(_ lu: Components.Schemas.ConseilEnregistre) { self.init(lu.agAnnee, lu.agDate, lu.whatsappUrl, lu.membres) }

    private init(
        _ annee: Int?, _ date: String?, _ whatsapp: String, _ membres: [Components.Schemas.MembreConseilAdmin]
    ) {
        self.init(
            agAnnee: annee, agDate: date, whatsappUrl: whatsapp.nulSiVide, membres: membres.map(MembreConseil.init))
    }
}

extension MembreConseil {
    init(_ lu: Components.Schemas.MembreConseilAdmin) {
        self.init(
            id: lu.id, genre: lu.genre, prenom: lu.prenom, nom: lu.nom, batimentId: lu.batimentId,
            batimentNom: lu.batimentNom, etage: lu.etage, etageLibelle: lu.etageLibelle.nulSiVide,
            estGestionnaireSite: lu.estGestionnaireSite, estPresident: lu.estPresident, photoUrl: lu.photoUrl,
            userId: lu.userId)
    }
}

extension SyndicCS {
    init(_ lu: Components.Schemas.InfoSyndicAdmin) {
        self.init(lu.nomSyndic, lu.nomSyndicSource.rawValue, lu.adresse, lu.siteWeb, lu.membres)
    }

    /// La fiche ENREGISTRÉE que rend le `PUT` : la même forme que la lecture.
    init(_ lu: Components.Schemas.SyndicEnregistre) {
        self.init(lu.nomSyndic, lu.nomSyndicSource.rawValue, lu.adresse, lu.siteWeb, lu.membres)
    }

    private init(
        _ nom: String, _ source: String, _ adresse: String, _ site: String?,
        _ membres: [Components.Schemas.MembreSyndicAdmin]
    ) {
        self.init(
            nomSyndic: nom.nulSiVide, nomSyndicSource: source, adresse: adresse.nulSiVide, siteWeb: site,
            membres: membres.map(MembreSyndic.init))
    }
}

extension MembreSyndic {
    init(_ lu: Components.Schemas.MembreSyndicAdmin) {
        self.init(
            id: lu.id, genre: lu.genre, prenom: lu.prenom, nom: lu.nom, fonction: lu.fonction, email: lu.email,
            telephone: lu.telephone, telephones: lu.telephones, estPrincipal: lu.estPrincipal, photoUrl: lu.photoUrl,
            userId: lu.userId)
    }
}

extension Rapprochement {
    init(_ lu: Components.Schemas.Rapprochement) {
        self.init(userId: lu.userId, batimentId: lu.batimentId, batimentNom: lu.batimentNom, etage: lu.etage)
    }
}
