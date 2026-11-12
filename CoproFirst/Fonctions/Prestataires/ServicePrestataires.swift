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
    /// « Prénom NOM », tel que le serveur l'affiche (`nom_affiche` de `PrestataireContactLu`,
    /// #135) ; `nil` pour un contact sans nom (le serveur sert alors `""`).
    var nomAffiche: String?
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
    /// Les numéros, un lien d'appel chacun : ceux que le serveur SERT, découpés et
    /// dédoublonnés par lui (`telephones`, #125) — l'app ne découpe pas `telephone`.
    var telephones: [String] = []
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
