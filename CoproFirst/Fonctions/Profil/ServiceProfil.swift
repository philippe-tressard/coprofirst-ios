// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Le compte de l'utilisateur dans la résidence ouverte (GET /auth/me, `UserRead`).
struct Compte: Hashable, Sendable {
    var prenom: String
    var nom: String
    var email: String
    var telephone: String?
    var societe: String?
    var fonction: String?
    let photo: String?
    let statut: String
    let roles: [String]
    let batimentNom: String?
    let actif: Bool
    let creeLe: Date
    let derniereConnexion: Date?
    /// Du JSON, tel que le serveur le garde : les clés jamais réglées en sont absentes.
    var preferences: String
    var restreindreAMesBatiments: Bool
    var refusTelemetrie: Bool
}

/// Ce qu'on corrige de son identité (PATCH /auth/me). Changer d'adresse demande le
/// mot de passe actuel ; la nouvelle adresse ne vaut qu'une fois confirmée.
struct SaisieIdentite: Hashable, Sendable {
    var prenom = ""
    var nom = ""
    var email = ""
    var telephone = ""
    var societe = ""
    var fonction = ""
    var motDePasseActuel = ""
}

/// Une demande de changement de profil ou de bâtiment (`DemandeModifRead`).
struct DemandeModification: Hashable, Sendable, Identifiable {
    let id: Int
    /// `en_attente`, `approuvee`, `rejetee`.
    let etat: String
    let statutSouhaite: String?
    let batimentSouhaite: String?
    let motifRefus: String?
    let creeLe: Date
}

/// Un bâtiment de la résidence (GET /auth/batiments).
struct BatimentResidence: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    let numero: String
}

/// Ce que l'écran Profil demande à une installation (#14). La photo, les étages et la
/// démarche « nouvel arrivant » restent au site pour l'instant ; l'écran le dit.
protocol ServiceProfil: Sendable {
    func compte(_ installation: Installation) async throws -> Compte
    /// PATCH /auth/me : l'identité ; `true` si un lien de confirmation est parti.
    func modifierIdentite(_ saisie: SaisieIdentite, ancienne: String, dans installation: Installation) async throws
        -> Bool
    /// POST /auth/change-password.
    func changerMotDePasse(actuel: String, nouveau: String, dans installation: Installation) async throws
    /// PATCH /auth/me : les préférences de notification et la restriction aux bâtiments.
    func enregistrerPreferences(_ json: String, restreindre: Bool, dans installation: Installation) async throws
    /// PATCH /auth/me `saisie_affaire` : `essentielle` ou `complete`, pour le COMPTE (#69).
    func choisirSaisie(_ mode: String, dans installation: Installation) async throws
    /// PATCH /auth/me/opt-out-telemetrie ; GET (export) et DELETE /auth/me/telemetrie.
    func refuserTelemetrie(_ refus: Bool, dans installation: Installation) async throws
    func exporterTelemetrie(_ installation: Installation) async throws -> URL
    func effacerTelemetrie(_ installation: Installation) async throws
    /// GET /auth/me/demandes-modification ; POST /auth/me/demande-modification ; GET /auth/batiments.
    func demandesModification(_ installation: Installation) async throws -> [DemandeModification]
    func demanderModification(statut: String?, batiment: Int?, motif: String, dans installation: Installation)
        async throws
    func batiments(_ installation: Installation) async throws -> [BatimentResidence]
}

extension Parcours {
    /// Les deux réalisations s'y conforment (`ProfilTests` le vérifie à la compilation).
    var serviceProfil: any ServiceProfil {
        // swiftlint:disable:next force_cast
        service as! any ServiceProfil
    }
}

extension SaisieIdentite {
    init(_ compte: Compte) {
        self.init(
            prenom: compte.prenom, nom: compte.nom, email: compte.email, telephone: compte.telephone ?? "",
            societe: compte.societe ?? "", fonction: compte.fonction ?? "")
    }

    /// L'adresse change-t-elle ? Comparée sans casse ni espaces autour, comme le site.
    func changeAdresse(_ ancienne: String) -> Bool {
        let propre = { (adresse: String) in adresse.trimmingCharacters(in: .whitespaces).lowercased() }
        return propre(email) != propre(ancienne)
    }

    /// Prénom, nom et adresse sont obligatoires ; une nouvelle adresse demande le mot de passe.
    func complete(_ ancienne: String) -> Bool {
        let requis = [prenom, nom, email].allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return requis && (!changeAdresse(ancienne) || !motDePasseActuel.isEmpty)
    }
}

extension String {
    /// Une saisie vide part à `null` — le site fait de même.
    var nulSiVide: String? {
        let propre = trimmingCharacters(in: .whitespaces)
        return propre.isEmpty ? nil : propre
    }
}
