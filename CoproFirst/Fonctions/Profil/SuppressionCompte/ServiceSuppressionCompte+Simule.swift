// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// La demande de suppression simulée : lue des fixtures, changée par les gestes de CE
/// service. Comme le serveur : « refuse » comme mot de passe est refusé (400), une
/// seconde demande ouverte aussi (409) ; retirer sans demande, 404.
extension ServiceSimule: ServiceSuppressionCompte {
    func etatSuppression(_ installation: Installation) async throws -> EtatSuppressionCompte {
        try await Task.sleep(for: .milliseconds(250))
        return try modifierSimule(depuis: FixturesSuppressionCompte.etatLu) { $0 }
    }

    func demanderSuppression(motDePasse: String, motif: String, dans installation: Installation) async throws
        -> DemandeSuppressionCompte {
        try await Task.sleep(for: .milliseconds(300))
        if motDePasse == "refuse" { throw ErreurService.refus(.init(phrase: "Mot de passe incorrect.")) }
        let demande = try FixturesSuppressionCompte.demandeLue()
        return try modifierSimule(depuis: FixturesSuppressionCompte.etatLu) { etat in
            if etat.demande != nil {
                throw ErreurService.refus(.init(phrase: "Une demande de suppression est déjà en cours."))
            }
            etat = EtatSuppressionCompte(demande: demande, delaiJours: etat.delaiJours, consequences: etat.consequences)
            return demande
        }
    }

    func retirerDemandeSuppression(_ installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
        try modifierSimule(depuis: FixturesSuppressionCompte.etatLu) { etat in
            guard etat.demande != nil else { throw ErreurService.depuisLecture(404) }
            etat = EtatSuppressionCompte(demande: nil, delaiJours: etat.delaiJours, consequences: etat.consequences)
        }
    }
}
#endif
