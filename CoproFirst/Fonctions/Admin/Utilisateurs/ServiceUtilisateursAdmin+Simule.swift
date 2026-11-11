// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// « Utilisateurs » simulé : les comptes inventés de `FixturesUtilisateursAdmin`, lus
/// comme le service réel les lit ; les gestes changent la liste de CE service, comme le
/// serveur — le premier bannissement est probatoire (un mois), le suivant définitif.
///
/// Un geste de rôle change les rôles du compte et inverse le geste servi sur ce rôle ;
/// ce faux serveur ne recalcule pas la règle (`utils/gestes_roles`) : elle n'est écrite
/// qu'au serveur, et l'app n'en tient aucune copie.
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
                ? BanCommunaute(interdit: false, jusquAu: nil, banniServi: false)
                : BanCommunaute(
                    interdit: dejaBanni, jusquAu: dejaBanni ? nil : .now.addingTimeInterval(30 * 86_400),
                    banniServi: true)
            return comptes[rang].ban
        }
    }

    func changerRole(_ id: Int, role: String, geste: GesteRole, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
        try modifierSimule(depuis: FixturesUtilisateursAdmin.lus) { comptes in
            guard let rang = comptes.firstIndex(where: { $0.id == id }),
                let servi = comptes[rang].gestesRoles?.firstIndex(where: { $0.role == role && $0.geste == geste })
            else { throw ErreurService.refus(.init(phrase: "Ce geste n'est plus possible : la liste a changé.")) }
            comptes[rang].roles.removeAll { $0 == role }
            if geste == .ajouter { comptes[rang].roles.append(role) }
            comptes[rang].gestesRoles?[servi] = GesteDeRole(role: role, geste: geste == .ajouter ? .retirer : .ajouter)
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
#endif
