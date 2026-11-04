// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Un compte inventé, pour les aperçus, les tests et les captures : aucun nom de
/// personne, aucune requête. Les écritures réussissent ; « refuse » comme mot de
/// passe actuel est refusé, comme le ferait le serveur.
extension ServiceSimule: ServiceProfil {
    func compte(_ installation: Installation) async throws -> Compte {
        try await Task.sleep(for: .milliseconds(350))
        return Compte(
            prenom: "Résident", nom: "Exemple", email: "resident@exemple.fr", telephone: nil, societe: nil,
            fonction: nil, photo: nil, statut: profilSimule.statut ?? "", roles: profilSimule.roles, batimentNom: "A",
            actif: true, creeLe: Date.now.addingTimeInterval(-86_400 * 420),
            derniereConnexion: Date.now.addingTimeInterval(-3_600), preferences: #"{"mon_batiment_mail": true}"#,
            restreindreAMesBatiments: false, refusTelemetrie: false)
    }

    func modifierIdentite(_ saisie: SaisieIdentite, ancienne: String, dans installation: Installation)
        async throws -> Bool {
        try await Task.sleep(for: .milliseconds(300))
        if saisie.changeAdresse(ancienne), saisie.motDePasseActuel == "refuse" {
            throw ErreurService.identifiantsRefuses
        }
        return saisie.changeAdresse(ancienne)
    }

    func changerMotDePasse(actuel: String, nouveau: String, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
        if actuel == "refuse" { throw ErreurService.refus(.init(phrase: "Mot de passe actuel incorrect.")) }
    }

    func enregistrerPreferences(_ json: String, restreindre: Bool, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
    }

    func refuserTelemetrie(_ refus: Bool, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(200))
    }

    func exporterTelemetrie(_ installation: Installation) async throws -> URL {
        try await Task.sleep(for: .milliseconds(250))
        let fichier = FileManager.default.temporaryDirectory.appending(path: "mes-donnees-telemetrie.json")
        try Data(#"{"evenements": []}"#.utf8).write(to: fichier, options: .atomic)
        return fichier
    }

    func effacerTelemetrie(_ installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(200))
    }

    func demandesModification(_ installation: Installation) async throws -> [DemandeModification] {
        try await Task.sleep(for: .milliseconds(300))
        return [
            DemandeModification(
                id: 1, etat: "approuvee", statutSouhaite: "copropriétaire_résident", batimentSouhaite: nil,
                motifRefus: nil, creeLe: Date.now.addingTimeInterval(-86_400 * 300)),
        ]
    }

    func demanderModification(statut: String?, batiment: Int?, motif: String, dans installation: Installation)
        async throws {
        try await Task.sleep(for: .milliseconds(300))
    }

    func batiments(_ installation: Installation) async throws -> [BatimentResidence] {
        try await Task.sleep(for: .milliseconds(200))
        return [BatimentResidence(id: 1, numero: "A"), BatimentResidence(id: 2, numero: "B")]
    }
}
