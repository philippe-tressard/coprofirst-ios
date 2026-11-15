// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

// La résiliation et le remplacement d'un contrat (#185, coprofirst#2712) : lus par le type
// généré — rien n'est recalculé ; non servis, la carte ne montre rien de plus.

private func pastilles(_ id: Int) throws -> [String] {
    try #require(try FixturesPrestataires.contratsLus().first { $0.id == id }).remplacement.pastilles
}

@Test func lAncienContratDitParQuiIlEstRemplaceEtDesQuand() throws {
    #expect(try pastilles(2) == ["🔁 Remplacé par Protection Incendie Exemple ·\u{00A0}dès le 01/12/2026"])
}

@Test func leNouveauContratDitQuiIlRemplace() throws {
    #expect(try pastilles(4) == ["🔁 Remplace Contrôles Sécurité Exemple (résilié au 30/11/2026)"])
}

@Test func unContratSansRemplacementNeMontreRien() throws {
    #expect(try pastilles(1).isEmpty)
    #expect(try pastilles(3).isEmpty, "les champs absents : rien")
}

/// Un contrat dont la réponse ne porte aucun des champs (leurs défauts du contrat).
@Test func unContratSansCesChampsNeMontreRienDePlus() throws {
    let servi = #"""
        [{"id": 2, "copropriete_id": 1, "prestataire_id": 2, "type_equipement": "incendie",
          "libelle": "Vérification des extincteurs", "date_debut": "2023-06-01", "actif": true}]
        """#
    let generes = try Relecture.generee([Components.Schemas.ContratRead].self, json: servi)
    let contrat = try #require(Contrat.lus(generes).first)
    #expect(contrat.remplacement == RemplacementContrat())
    #expect(!contrat.remplacement.estDatee, "« Sans échéance » reste affiché")
}

@Test func uneResiliationSansSuiteSeDitAuOuLeSelonQuElleEstPassee() {
    let aVenir = RemplacementContrat(resilieLe: "2026-12-31", resilie: false)
    #expect(aVenir.pastilles == ["Résilié au 31/12/2026"])
    #expect(aVenir.estDatee)
    let passee = RemplacementContrat(resilieLe: "2026-06-30", resilie: true)
    #expect(passee.pastilles == ["Résilié le 30/06/2026"])
}

@Test func leDetailNommeLeContratLieEtSonPrestataire() throws {
    let lie = try #require(try FixturesPrestataires.contratsLus().first { $0.id == 2 }?.remplacement.remplacePar)
    #expect(TextesPrestataires.lie(lie) == "Vérification des extincteurs —\u{00A0}Protection Incendie Exemple")
}
