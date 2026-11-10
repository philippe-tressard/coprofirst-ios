// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// « Utilisateurs » simulé : les comptes inventés de `FixturesUtilisateursAdmin`, lus
/// comme le service réel les lit ; les gestes changent la liste de CE service, comme le
/// serveur — le premier bannissement est probatoire (un mois), le suivant définitif.
extension ServiceSimule: ServiceUtilisateursAdmin {
    func utilisateurs(_ installation: Installation) async throws -> [UtilisateurAdmin] {
        try await Task.sleep(for: .milliseconds(300))
        return try modifierSimule(depuis: FixturesUtilisateursAdmin.lus) { $0 }
    }

    func bannirCommunaute(_ id: Int, interdit: Bool, dans installation: Installation) async throws -> BanCommunaute {
        try await Task.sleep(for: .milliseconds(300))
        return try modifierSimule(depuis: FixturesUtilisateursAdmin.lus) { comptes in
            guard let rang = comptes.firstIndex(where: { $0.id == id }) else {
                throw ErreurService.refus(.init(phrase: "Utilisateur introuvable"))
            }
            let dejaBanni = comptes[rang].ban.jusquAu != nil
            comptes[rang].ban =
                !interdit
                ? BanCommunaute(interdit: false, jusquAu: nil)
                : BanCommunaute(interdit: dejaBanni, jusquAu: dejaBanni ? nil : .now.addingTimeInterval(30 * 86_400))
            return comptes[rang].ban
        }
    }

    func relancerRapprochement(_ id: Int, dans installation: Installation) async throws -> PhraseAvis {
        try await Task.sleep(for: .milliseconds(400))
        return try FixturesUtilisateursAdmin.annonceDuRapprochement()
    }

    func supprimerUtilisateur(_ id: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
        try modifierSimule(depuis: FixturesUtilisateursAdmin.lus) { $0.removeAll { $0.id == id } }
    }
}
