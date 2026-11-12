// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// La demande de suppression de compte (#166, coprofirst#2699) : ce que la revue d'Apple
/// exige. Le délai et les conséquences sont SERVIS ; une demande traitée ou retirée n'est
/// plus « en cours ».
struct SuppressionCompteTests {
    @Test func lesDeuxServicesSaventDemander() {
        let _: any ServiceSuppressionCompte = ServiceAPI()
        let _: any ServiceSuppressionCompte = ServiceSimule()
    }

    @Test func lEtatServiEstLuTelQuel() throws {
        let etat = try FixturesSuppressionCompte.etatLu()
        #expect(etat.demande == nil)
        #expect(etat.delaiJours == 30)
        #expect(etat.consequences.count == 4)
        // Les continuations de ligne du JSON simulé ne laissent ni double espace ni retour.
        #expect(etat.consequences.allSatisfy { !$0.contains("  ") && !$0.contains("\n") })
    }

    @Test func demanderPuisRetirer() async throws {
        let service = ServiceSimule()
        let ici = ServiceSimule.residence
        let demande = try await service.demanderSuppression(motDePasse: "secret", motif: "", dans: ici)
        #expect(demande.ouverte)
        #expect(try await service.etatSuppression(ici).demande == demande)
        await #expect(throws: ErreurService.self) {
            _ = try await service.demanderSuppression(motDePasse: "secret", motif: "", dans: ici)
        }
        try await service.retirerDemandeSuppression(ici)
        #expect(try await service.etatSuppression(ici).demande == nil)
    }

    @Test func unMotDePasseFauxEstRefuse() async throws {
        let ici = ServiceSimule.residence
        await #expect(throws: ErreurService.self) {
            _ = try await ServiceSimule().demanderSuppression(motDePasse: "refuse", motif: "", dans: ici)
        }
    }
}
