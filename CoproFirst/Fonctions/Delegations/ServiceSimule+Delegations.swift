// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Des délégations inventées, pour les aperçus, les tests et les captures : des prénoms
/// d'exemple, aucune personne réelle, aucune requête. Les gestes changent la liste de
/// CE service (un magasin par instance : deux tests ne se marchent pas dessus).
extension ServiceSimule: ServiceDelegations {
    /// Le compte simulé — le même que la Communauté simulée (`moiCommunaute`).
    static let moiDelegations = 7

    func delegations(_ installation: Installation) async throws -> ListeDelegations {
        try await Task.sleep(for: .milliseconds(350))
        return ListeDelegations(delegations: DelegationsSimulees.pour(self).lire(), moi: Self.moiDelegations)
    }

    func residentsDelegables(_ installation: Installation) async throws -> [ResidentDelegable] {
        try await Task.sleep(for: .milliseconds(200))
        return [
            ResidentDelegable(id: 3, prenom: "Lucie", nom: "Exemple", email: "lucie@exemple.fr", actif: true),
            ResidentDelegable(id: 4, prenom: "Marc", nom: "Démo", email: "marc@exemple.fr", actif: true),
            ResidentDelegable(id: 7, prenom: "Camille", nom: "Essai", email: "camille@exemple.fr", actif: true),
            ResidentDelegable(id: 9, prenom: "Paul", nom: "Fictif", email: "paul@exemple.fr", actif: false),
        ]
    }

    func creerDelegation(_ saisie: SaisieDelegation, dans installation: Installation) async throws -> Delegation {
        try await Task.sleep(for: .milliseconds(300))
        guard let mandant = saisie.mandant, let aidant = saisie.aidant, mandant != aidant else {
            throw ErreurService.refus(.init(phrase: "Le mandant et l'aidant doivent être différents"))
        }
        let residents = try await residentsDelegables(installation)
        let nom = { (id: Int) in residents.first { $0.id == id }.map { "\($0.prenom ?? "") \($0.nom ?? "")" } ?? "?" }
        let creee = Delegation(
            id: 100 + Int.random(in: 0..<900), mandantId: mandant, mandantNom: nom(mandant), aidantId: aidant,
            aidantNom: nom(aidant), statut: "en_attente", motif: saisie.motif, dateDebut: Self.jour(0),
            dateFin: saisie.dateFin.map { FormatsDuSite.jourISO($0) })
        DelegationsSimulees.pour(self).ajouter(creee)
        return creee
    }

    func accepterDelegation(_ id: Int, dans installation: Installation) async throws -> Delegation {
        try await Task.sleep(for: .milliseconds(300))
        return try DelegationsSimulees.pour(self).changer(id) { delegation in
            guard delegation.statut == "en_attente" else {
                throw ErreurService.refus(
                    .init(phrase: "Impossible d'accepter : cette délégation n'est plus en attente."))
            }
            delegation.statut = "active"
        }
    }

    func revoquerDelegation(_ id: Int, dans installation: Installation) async throws -> Delegation {
        try await Task.sleep(for: .milliseconds(300))
        return try DelegationsSimulees.pour(self).changer(id) { delegation in
            guard delegation.revocable else { throw ErreurService.refus(.init(phrase: "Délégation déjà terminée")) }
            delegation.statut = "revoquee"
        }
    }

    /// Un jour ISO, à `jours` d'aujourd'hui.
    fileprivate static func jour(_ jours: Int) -> String {
        FormatsDuSite.jourISO(Date.now.addingTimeInterval(Double(jours) * 86_400))
    }
}

/// Les délégations d'UN service simulé : la liste de départ, puis ce que ses gestes en font.
private final class DelegationsSimulees: @unchecked Sendable {
    private static let verrouGlobal = NSLock()
    nonisolated(unsafe) private static var parService: [ObjectIdentifier: DelegationsSimulees] = [:]
    private let verrou = NSLock()
    private var liste: [Delegation] = [
        Delegation(
            id: 12, mandantId: 3, mandantNom: "Lucie Exemple", aidantId: 7, aidantNom: "Camille Essai",
            statut: "en_attente", motif: "Assistance pendant une convalescence", dateDebut: ServiceSimule.jour(-2),
            dateFin: ServiceSimule.jour(88)),
        Delegation(
            id: 8, mandantId: 4, mandantNom: "Marc Démo", aidantId: 3, aidantNom: "Lucie Exemple",
            statut: "active", motif: "Assistance personne âgée", dateDebut: ServiceSimule.jour(-120), dateFin: nil),
        Delegation(
            id: 5, mandantId: 9, mandantNom: "Paul Fictif", aidantId: 4, aidantNom: "Marc Démo", statut: "revoquee",
            motif: "", dateDebut: ServiceSimule.jour(-400), dateFin: ServiceSimule.jour(-30)),
    ]

    static func pour(_ service: ServiceSimule) -> DelegationsSimulees {
        verrouGlobal.withLock {
            let cle = ObjectIdentifier(service)
            if let magasin = parService[cle] { return magasin }
            let neuf = DelegationsSimulees()
            parService[cle] = neuf
            return neuf
        }
    }

    func lire() -> [Delegation] { verrou.withLock { liste } }

    func ajouter(_ delegation: Delegation) { verrou.withLock { liste.insert(delegation, at: 0) } }

    func changer(_ id: Int, _ geste: (inout Delegation) throws -> Void) throws -> Delegation {
        try verrou.withLock {
            guard let index = liste.firstIndex(where: { $0.id == id }) else { throw ErreurService.introuvable }
            try geste(&liste[index])
            return liste[index]
        }
    }
}
