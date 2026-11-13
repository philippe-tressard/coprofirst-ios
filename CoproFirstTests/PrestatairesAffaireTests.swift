// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

/// Plusieurs prestataires par affaire (#181, coprofirst#2704, contrat 1.28.0) : la liste
/// servie au-dessus du plancher, le repli sur le seul prestataire d'une installation
/// antérieure, « +N » au Kanban, et `prestataire_ids` envoyé seulement s'il a changé.
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

    /// Une installation antérieure au contrat 1.28.0 ne sert pas la liste : le seul
    /// prestataire qu'elle sert, comme avant — et aucun droit d'en changer.
    @Test func sansListeServieLeSeulPrestataireCommeAvant() throws {
        let ancienne = try #require(try FixturesDetailAffaire.lue(44))
        #expect(ancienne.prestataires == [PrestataireAffaire(id: nil, nom: "Ramonage Exemple (fictif)")])
        #expect(ancienne.intervenant == "Ramonage Exemple (fictif) · ↺ 1×/an")
        #expect(!ancienne.droits.changerPrestataires)
        let ticket = try Relecture.generee([Components.Schemas.TicketRead].self, json: FixturesDetailAffaire.affaires)
            .first { $0.id == 45 }
        let sansCorps = DetailAffaire.lue(try #require(ticket), evolutions: [])
        #expect(sansCorps.prestataires == [parc], "corps absent : `prestataire_id` et `prestataire_nom`")
        let illisible = DetailAffaire.lue(try #require(ticket), evolutions: [], corps: Data("{".utf8))
        #expect(illisible.prestataires == [parc] && !illisible.droits.changerPrestataires, "illisible : défaut fermé")
    }

    @Test func uneListeServieVideNeRetombePasSurLeRepli() throws {
        let affaire = try #require(try FixturesDetailAffaire.lue(41))
        #expect(affaire.prestataires.isEmpty && affaire.intervenant == nil)
    }

    // MARK: - Le Kanban

    @Test func laCarteDitLePremierPuisPlusN() {
        #expect(TextesPrestatairesAffaire.carte([]) == nil)
        #expect(TextesPrestatairesAffaire.carte(["A"]) == "A")
        #expect(TextesPrestatairesAffaire.carte(["A", "B", "C"]) == "A +2")
    }

    @Test func laListeLitLesPrestatairesParLigne() throws {
        let json = #"[{"id": 40, "prestataires": [{"id": 3, "nom": "X"}, {"id": 4, "nom": "Y"}]}, {"id": 41}]"#
        let servis = Relecture.auDessusDuPlancher(parLigne: PrestatairesServis.self, corps: Data(json.utf8))
        #expect(servis[40]?.prestataires?.map(\.nom) == ["X", "Y"])
        #expect(servis[41]?.prestataires == nil, "ligne sans la liste : le repli")
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
