// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

/// Plusieurs prestataires par affaire (#181, coprofirst#2704) : la liste servie, lue par le
/// type généré, « +N » au Kanban, et `prestataire_ids` envoyé seulement s'il a changé.
@MainActor
struct PrestatairesAffaireTests {
    private let parc = PrestataireAffaire(id: 1, nom: "Ascenseurs du Parc (fictif)")
    private let controles = PrestataireAffaire(id: 2, nom: "Contrôles Sécurité Exemple")

    // MARK: - La fiche

    @Test func laFicheLitLaListeServieUneLigneParPrestataire() throws {
        let affaire = try #require(try FixturesDetailAffaire.lue(45))
        #expect(affaire.prestataires == [parc, controles])
        #expect(affaire.intervenants == [parc.nom, "\(controles.nom) · ↺ Mensuel"], "le rythme après le dernier")
        #expect(affaire.intervenant == "\(parc.nom), \(controles.nom) · ↺ Mensuel")
        #expect(!affaire.droits.changerPrestataires, "servi à un résident : non")
    }

    @Test func uneAffaireAUnSeulPrestataireLeDitAvecSonRythme() throws {
        let affaire = try #require(try FixturesDetailAffaire.lue(44))
        #expect(affaire.prestataires == [PrestataireAffaire(id: 9, nom: "Ramonage Exemple (fictif)")])
        #expect(affaire.intervenant == "Ramonage Exemple (fictif) · ↺ 1×/an")
        #expect(!affaire.droits.changerPrestataires)
    }

    @Test func uneListeServieVideNeMontreAucunPrestataire() throws {
        let affaire = try #require(try FixturesDetailAffaire.lue(41))
        #expect(affaire.prestataires.isEmpty && affaire.intervenant == nil)
    }

    // MARK: - Le Kanban

    @Test func laCarteDitLePremierPuisPlusN() {
        #expect(TextesPrestatairesAffaire.carte([]) == nil)
        #expect(TextesPrestatairesAffaire.carte(["A"]) == "A")
        #expect(TextesPrestatairesAffaire.carte(["A", "B", "C"]) == "A +2")
    }

    @Test func laListeLitLesPrestatairesDeChaqueAffaire() throws {
        let tickets = try Relecture.generee([Components.Schemas.TicketRead].self, json: FixturesDetailAffaire.affaires)
        let lues = tickets.map(Affaire.init(ticket:))
        #expect(
            lues.first { $0.id == 45 }?.prestataires == ["Ascenseurs du Parc (fictif)", "Contrôles Sécurité Exemple"])
        #expect(lues.first { $0.id == 41 }?.prestataires == [], "sans liste servie : aucun")
    }

    @Test func lApercuDuKanbanPorteUneAffaireADeuxPrestataires() {
        let affaire = Apercu.affaires.first { $0.prestataires.count > 1 }
        #expect(affaire.flatMap { TextesPrestatairesAffaire.carte($0.prestataires) } == "Ascenseurs du Val +1")
    }

    // MARK: - ✏️ Modifier

    private func modifiable(_ droit: Bool = true) throws -> DetailAffaire {
        var affaire = try #require(try FixturesDetailAffaire.lue(45))
        affaire.droits.changerPrestataires = droit
        return affaire
    }

    @Test func laListeNePartQueSiElleAChange() throws {
        let origine = try modifiable()
        var saisie = SaisieAffaire(modifiant: origine)
        #expect(saisie.edition(depuis: origine).vide, "intacte : rien ne part")
        saisie.prestataires.swapAt(0, 1)
        #expect(saisie.edition(depuis: origine) == EditionAffaire(prestataires: [2, 1]), "l'ordre compte")
        saisie.prestataires.removeAll { $0.id == 1 }
        #expect(saisie.edition(depuis: origine) == EditionAffaire(prestataires: [2]))
        saisie.prestataires.removeAll()
        #expect(saisie.edition(depuis: origine) == EditionAffaire(prestataires: []), "vider la liste part aussi")
    }

    @Test func sansLeDroitServiLaListeNePartPas() throws {
        let origine = try modifiable(false)
        var saisie = SaisieAffaire(modifiant: origine)
        saisie.prestataires.removeAll()
        #expect(saisie.edition(depuis: origine).vide)
    }

    @Test func leServeurSimuleRemplaceLaListeDuConseilEtIgnoreCelleDuResident() async throws {
        let service = ServiceSimule(delai: .zero)
        let residence = ServiceSimule.residence
        #expect(try service.detailSimule(45).droits.changerPrestataires, "le conseil, affaire du bâti ouverte")
        try await service.enregistrer(EditionAffaire(prestataires: [3, 1]), de: 45, dans: residence)
        #expect(try service.detailSimule(45).prestataires.map(\.id) == [3, 1])
        await #expect(throws: ErreurService.self) {
            try await service.enregistrer(EditionAffaire(prestataires: [999]), de: 45, dans: residence)
        }

        let resident = ServiceSimule(delai: .zero)
        resident.profilSimule.roles.removeAll { $0 == "conseil_syndical" }
        resident.profilSimule.estModerateur = false
        // L'auteur de 41 garde le crayon, sans le droit sur les prestataires.
        #expect(try resident.detailSimule(41).droits.corriger && !resident.detailSimule(41).droits.changerPrestataires)
        try await resident.enregistrer(EditionAffaire(prestataires: [3]), de: 41, dans: residence)
        #expect(try resident.detailSimule(41).prestataires.isEmpty, "ignorée, comme le serveur")
    }
}
