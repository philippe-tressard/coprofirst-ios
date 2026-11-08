// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Des délégations inventées, pour les aperçus, les tests et les captures : des prénoms
/// d'exemple, aucune personne réelle, aucune requête. La liste de départ est le JSON de
/// la route (`FixturesDelegations`), lu comme le service réel le lit ; les gestes changent
/// la liste de CE service (un magasin par instance : deux tests ne se marchent pas dessus).
extension ServiceSimule: ServiceDelegations {
    /// Le compte simulé — le même que la Communauté simulée (`moiCommunaute`).
    static let moiDelegations = 7

    func delegations(_ installation: Installation) async throws -> [Delegation] {
        try await Task.sleep(for: .milliseconds(350))
        return try modifierSimule(depuis: FixturesDelegations.delegationsLues) { $0 }
    }

    func residentsDelegables(_ installation: Installation) async throws -> [ResidentDelegable] {
        try await Task.sleep(for: .milliseconds(200))
        return try FixturesDelegations.residentsLus()
    }

    func creerDelegation(_ saisie: SaisieDelegation, dans installation: Installation) async throws -> Delegation {
        try await Task.sleep(for: .milliseconds(300))
        guard let mandant = saisie.mandant, let aidant = saisie.aidant, mandant != aidant else {
            throw ErreurService.refus(.init(phrase: "Le mandant et l'aidant doivent être différents"))
        }
        let residents = try FixturesDelegations.residentsLus()
        let nom = { (id: Int) in residents.first { $0.id == id }.map { "\($0.prenom ?? "") \($0.nom ?? "")" } ?? "?" }
        // Ce que le serveur rendrait : en attente, que seul l'aidant accepte.
        let creee = Delegation(
            id: 100 + Int.random(in: 0..<900), mandantId: mandant, mandantNom: nom(mandant), aidantId: aidant,
            aidantNom: nom(aidant), statut: "en_attente", motif: saisie.motif, dateDebut: FormatsDuSite.jourISO(.now),
            dateFin: saisie.dateFin.map { FormatsDuSite.jourISO($0) },
            peutAccepter: aidant == Self.moiDelegations, peutRevoquer: true)
        try modifierSimule(depuis: FixturesDelegations.delegationsLues) { $0.insert(creee, at: 0) }
        return creee
    }

    func accepterDelegation(_ id: Int, dans installation: Installation) async throws -> Delegation {
        try await Task.sleep(for: .milliseconds(300))
        return try changer(id) { delegation in
            guard delegation.peutAccepter else {
                throw ErreurService.refus(
                    .init(phrase: "Impossible d'accepter : cette délégation n'est plus en attente."))
            }
            delegation.statut = "active"
            delegation.peutAccepter = false
        }
    }

    func revoquerDelegation(_ id: Int, dans installation: Installation) async throws -> Delegation {
        try await Task.sleep(for: .milliseconds(300))
        return try changer(id) { delegation in
            guard delegation.peutRevoquer else { throw ErreurService.refus(.init(phrase: "Délégation déjà terminée")) }
            delegation.statut = "revoquee"
            delegation.peutAccepter = false
            delegation.peutRevoquer = false
        }
    }

    private func changer(_ id: Int, _ geste: (inout Delegation) throws -> Void) throws -> Delegation {
        try modifierSimule(depuis: FixturesDelegations.delegationsLues) { liste in
            guard let index = liste.firstIndex(where: { $0.id == id }) else { throw ErreurService.introuvable }
            try geste(&liste[index])
            return liste[index]
        }
    }
}
