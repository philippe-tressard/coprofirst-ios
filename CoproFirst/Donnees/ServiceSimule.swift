// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Une installation simulée, pour les aperçus et les tests d'interface : aucune
/// requête ne part. Tout y est inventé — aucun nom de personne, aucune adresse réelle.
final class ServiceSimule: ServiceCoproFirst {
    static let residence = Installation(
        adresse: URL(string: "https://tilleuls.exemple.fr")!, nom: "Résidence Les Tilleuls", aUnLogo: false)

    /// Le délai d'une réponse : assez pour voir le squelette, pas pour attendre.
    private let delai: Duration

    init(delai: Duration = .milliseconds(450)) {
        self.delai = delai
    }

    func decouvrir(_ adresse: URL) async throws -> Installation {
        try await Task.sleep(for: delai)
        switch adresse.host() {
        case "inconnue.exemple.fr": throw ErreurService.hoteInconnu
        case "injoignable.exemple.fr": throw ErreurService.injoignable
        default: return Installation(adresse: adresse, nom: Self.residence.nom, aUnLogo: false)
        }
    }

    func connecter(_ installation: Installation, email: String, motDePasse: String) async throws {
        try await Task.sleep(for: delai)
        if motDePasse == "refuse" { throw ErreurService.identifiantsRefuses }
    }

    func aUneSessionGardee(_ installation: Installation) -> Bool { false }

    func reprendre(_ installation: Installation) async throws {
        throw ErreurService.sessionExpiree
    }

    func affaires(_ installation: Installation) async throws -> [Affaire] {
        try await Task.sleep(for: delai)
        return Self.affaires
    }

    func peutArchiver(_ installation: Installation) -> Bool { true }

    func archiver(_ affaire: Affaire, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(150))
    }

    static let affaires: [Affaire] = {
        let maintenant = Date(timeIntervalSince1970: 1_793_610_000)  // 02/11/2026
        func jours(_ n: Double) -> Date { maintenant.addingTimeInterval(-n * 86_400) }
        return [
            Affaire(
                id: 41, numero: "A-0041", titre: "Fuite d'eau au plafond du parking",
                apercu: "Une infiltration goutte au niveau -1, place 12. Le sol est glissant : un seau a été posé "
                    + "en attendant le plombier. Merci de contourner la zone.",
                creeLe: jours(0.2), statut: "en_cours", urgente: true, meConcerne: true,
                lieu: "Parking, niveau -1", messages: 6),
            Affaire(
                id: 40, numero: "A-0040", titre: "Ascenseur du bâtiment B à l'arrêt",
                apercu: "L'ascenseur reste bloqué au troisième étage depuis ce matin. Le prestataire est prévenu "
                    + "et doit passer dans la journée.",
                creeLe: jours(1), statut: "chez_prestataire", urgente: true, meConcerne: false,
                lieu: "Bâtiment B", messages: 3),
            Affaire(
                id: 38, numero: "A-0038", titre: "Ravalement de la façade côté rue",
                apercu: "Le devis retenu en assemblée générale sera présenté au conseil syndical. Les échafaudages "
                    + "sont prévus au printemps, pour six semaines environ.",
                creeLe: jours(6), statut: "en_ag", urgente: false, meConcerne: true,
                lieu: "Façade nord", messages: 12),
            Affaire(
                id: 35, numero: "A-0035", titre: "Éclairage du hall en panne",
                apercu: "Deux plafonniers ne s'allument plus dans le hall d'entrée. Les ampoules ont été changées, "
                    + "le problème vient du minuteur.",
                creeLe: jours(9), statut: "ouvert", urgente: false, meConcerne: false,
                lieu: "Hall A", messages: 2),
            Affaire(
                id: 31, numero: "A-0031", titre: "Portail du garage remis en service",
                apercu: "La télécommande fonctionne de nouveau après le remplacement de la carte électronique.",
                creeLe: jours(21), statut: "résolu", urgente: false, meConcerne: true,
                lieu: "Garage", messages: 4),
        ]
    }()
}
