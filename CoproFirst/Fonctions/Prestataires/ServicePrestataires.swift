// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que « Prestataires » demande à une installation (#13), en LECTURE. Réalisé par
/// `ServiceAPI` (client généré) et `ServiceSimule`, dans ce dossier.
///
/// Les gestes (créer, corriger, archiver, noter, relever un compteur) sont réservés
/// au conseil syndical et restent sur le site pour l'instant : l'écran le dit.
protocol ServicePrestataires: Sendable {
    /// GET /prestataires, ou /prestataires/archives.
    func prestataires(_ installation: Installation, archives: Bool) async throws -> [Prestataire]
    /// GET /prestataires/contrats, ou /prestataires/contrats/archives.
    func contrats(_ installation: Installation, archives: Bool) async throws -> [Contrat]
    /// GET /prestataires/notations : les avis du conseil syndical.
    func avis(_ installation: Installation) async throws -> [AvisPrestataire]
    /// GET /equipements : les équipements (libellés et ordre) — des données, pas une table.
    func equipements(_ installation: Installation) async throws -> [Equipement]
    /// GET /documents?contrat_id= : les documents d'un contrat.
    func documents(contrat: Int, dans installation: Installation) async throws -> [DocumentContrat]
    /// GET /prestataires/compteurs-config : les catégories de compteurs.
    func compteurs(_ installation: Installation) async throws -> [Compteur]
    /// GET /prestataires/releves?type_compteur= : les relevés d'un compteur.
    func releves(_ typeCompteur: String, dans installation: Installation) async throws -> [Releve]
}

extension Parcours {
    /// Le service de « Prestataires » (réalisé par les deux services de l'app :
    /// `ServicesDesMenusTests` le vérifie).
    var servicePrestataires: (any ServicePrestataires)? { service as? any ServicePrestataires }
}

struct ContactPrestataire: Hashable, Sendable {
    var prenom: String?
    var nom: String?
    var fonction: String?
    var telephone: String?
    var email: String?
    /// `nom_affiche` servi (`PrestataireContactLu`, contrat 1.25.0, #135) ; `nil` d'une
    /// installation antérieure.
    var nomServi: String?

    /// « Prénom NOM » servi ; à défaut, le repli. `nil` pour un contact sans nom.
    var nomAffiche: String? {
        let lu = FormatsDuSite.nom(affiche: nomServi, prenom: prenom, nom: nom)
        return lu == FormatsDuSite.tiret ? nil : lu
    }
}

struct Prestataire: Hashable, Sendable, Identifiable {
    let id: Int
    var nom: String
    var specialite: String
    var type: String?
    var telephone: String?
    var email: String?
    var adresse: String?
    var description: String?
    var contacts: [ContactPrestataire] = []
    /// Les numéros, un lien d'appel chacun : ceux que le serveur SERT (`telephones`,
    /// contrat 1.20.0, #125) ; d'une installation antérieure, `telephone` découpé comme
    /// avant (`Prestataire.lus`).
    var telephones: [String] = []
}

/// Ce que GET /prestataires (et ses archives) sert au-dessus du plancher, relu par
/// `Relecture.auDessusDuPlancher` : les numéros découpés et dédoublonnés par le serveur.
struct PrestataireAuDessusDuPlancher: Decodable, Identifiable {
    let id: Int
    var telephones: [String]?
}

extension Prestataire {
    /// La liste servie : le type généré, puis ce que le corps sert au-dessus du plancher
    /// — le MÊME branchement pour le service réel et l'API simulée.
    static func lus(_ generes: [Components.Schemas.PrestataireRead], corps: Data?) -> [Prestataire] {
        let servis = Relecture.auDessusDuPlancher(parLigne: PrestataireAuDessusDuPlancher.self, corps: corps)
        return generes.map { lu in
            var prestataire = Prestataire(lu)
            prestataire.telephones = servis[lu.id]?.telephones ?? decoupes(lu.telephone)
            return prestataire
        }
    }

    /// `telephonesDe` du site, pour une installation antérieure au contrat 1.20.0 qui ne
    /// sert pas `telephones` : découpés sur la virgule, sans vide ni doublon. Le jour où
    /// le plancher l'atteint, ce repli se retire.
    static func decoupes(_ champ: String?) -> [String] {
        var vus: [String] = []
        for brut in (champ ?? "").split(separator: ",") {
            let numero = brut.trimmingCharacters(in: .whitespaces)
            if !numero.isEmpty, !vus.contains(numero) { vus.append(numero) }
        }
        return vus
    }
}

struct Contrat: Hashable, Sendable, Identifiable {
    let id: Int
    var prestataireId: Int
    var libelle: String
    var typeEquipement: String
    var numeroContrat: String?
    var dateDebut: String
    var dureeValeur: Int?
    var dureeUnite: String?
    var frequenceType: String?
    var frequenceValeur: Int?
    /// « ↺ Mensuel » : la fréquence en clair, SERVIE (`frequence_libelle`, contrat ≤ 1.14.0,
    /// coprofirst#2507) — vide sans fréquence.
    var frequenceLibelle: String?
    var prochaineVisite: String?
    var notes: String?
}

struct AvisPrestataire: Hashable, Sendable, Identifiable {
    let id: Int
    var prestataireId: Int
    var note: Int
    var commentaire: String?
    var auteurNom: String?
    var creeLe: Date
}

struct Equipement: Hashable, Sendable {
    let code: String
    var libelle: String
    var ordre: Int
}

struct DocumentContrat: Hashable, Sendable, Identifiable {
    let id: Int
    var titre: String
    var fichierNom: String
}

struct Compteur: Hashable, Sendable, Identifiable {
    let id: Int
    var typeCompteur: String
    var libelle: String
    var ordre: Int
    var prestataireId: Int?
}

struct Releve: Hashable, Sendable, Identifiable {
    let id: Int
    var dateReleve: String
    var index: Int?
    var note: String?
    var photoUrl: String?
}
