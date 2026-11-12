// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

// « Nouvelle affaire » se compose selon la saisie du compte (#69) : le mode et les
// sections viennent du serveur ; l'app ne fait que les ranger.

/// La réponse de `GET /tickets/referentiels`, ses catégories simulées (générées depuis la
/// table du serveur), lue par le client GÉNÉRÉ puis par `ReferentielsAffaires`, la seule porte.
private func essentiellesServies() async throws -> SectionsEssentielles {
    let categories = FixturesCategoriesServies.categories
    let corps = #"{"categories": \#(categories), "statuts": [], "colonnes_kanban": [], "natures": []}"#
    let lu = try await client(servant: corps).getTicketsReferentiels().ok.body.json
    return ReferentielsAffaires(lu: lu).essentielles
}

@Test func lesSectionsDeLaFeuilleSontCellesDuCadreDuSite() {
    // Un identifiant qui n'existe pas au site ne serait jamais servi : la section ne se rangerait jamais.
    for section in SectionAffaire.allCases {
        #expect(TablesSaisie.sectionsAffaire.contains(section.rawValue), "\(section.rawValue) hors du cadre TICKET")
    }
    #expect(SectionAffaire.repliables == [.perimetre, .miseEnAvant])
}

@Test func leProfilNOffreQueLesModesQueLeServeurEnregistre() {
    // « Selon mon rôle » est refusé en 400 depuis coprofirst#2615 : jamais proposé.
    #expect(TablesSaisie.options.map(\.code) == ["essentielle", "complete"])
    #expect(ModeSaisie(servi: "role") == nil)
    #expect(ModeSaisie(servi: nil) == nil)
    #expect(ModeSaisie(servi: "essentielle") == .essentielle)
    #expect(ModeSaisie.complete.libelle == "Saisie complète")
}

@Test func enEssentielleLUrgenceSeRangeSaufPourUnePanneOuUnSinistre() async throws {
    let forme = FormeDeSaisie(mode: .essentielle, essentielles: try await essentiellesServies())
    #expect(forme.rangees(categorie: "panne").isEmpty)
    #expect(forme.rangees(categorie: "sinistre").isEmpty)
    #expect(forme.rangees(categorie: "question") == [.miseEnAvant])
    #expect(forme.rangees(categorie: "nuisance") == [.miseEnAvant])
    // Sans catégorie : la base, que toutes partagent — le lieu y est, l'urgence non.
    #expect(forme.rangees(categorie: "") == [.miseEnAvant])
    // Un bogue n'a ni lieu ni urgence : rien de lui ne se range.
    #expect(forme.rangees(categorie: "bug", eteintes: [.perimetre, .miseEnAvant]).isEmpty)
}

@Test func enCompleteOuSansSectionsServiesRienNeSeRange() async throws {
    let servies = try await essentiellesServies()
    #expect(FormeDeSaisie(mode: .complete, essentielles: servies).rangees(categorie: "question").isEmpty)
    let sansSections = FormeDeSaisie(mode: .essentielle, essentielles: nil)
    #expect(!sansSections.range)
    #expect(sansSections.rangees(categorie: "question").isEmpty)
    // La phrase ne renvoie pas à un groupe qui n'existe pas.
    #expect(sansSections.phrase(rangees: 0) == "Saisie essentielle. À changer dans votre profil.")
}

@Test func laFormeDuCompteSeComposeDuModeServi() {
    // La Création et l'Édition la composent par le même initialiseur (#110).
    let servies = SectionsEssentielles(["question": ["titre"]])
    #expect(
        FormeDeSaisie(servi: "essentielle", essentielles: servies)
            == FormeDeSaisie(mode: .essentielle, essentielles: servies))
    #expect(FormeDeSaisie(servi: "complete", essentielles: nil)?.mode == .complete)
    #expect(FormeDeSaisie(servi: nil, essentielles: servies) == nil, "un serveur qui ne sert pas la saisie")
    #expect(FormeDeSaisie(servi: "role", essentielles: servies) == nil, "un mot inconnu ne range rien")
}

@Test func laPhraseEtLIntituleDisentCeQuiEstRange() {
    let forme = FormeDeSaisie(mode: .essentielle, essentielles: SectionsEssentielles(["question": ["titre"]]))
    #expect(
        forme.phrase(rangees: 1)
            == "Saisie essentielle — les autres sections sont dans « Plus de détails ». À changer dans votre profil.")
    #expect(FormeDeSaisie.intitule(1) == "Plus de détails (1 section)")
    #expect(FormeDeSaisie.intitule(2) == "Plus de détails (2 sections)")
}

@Test func lesSectionsDeBaseSeDeduisentDeCeQueLeServeurSert() {
    let essentielles = SectionsEssentielles(["a": ["titre", "perimetre", "quand"], "b": ["titre", "perimetre"]])
    #expect(essentielles.pour("") == ["titre", "perimetre"])
    #expect(essentielles.pour("a") == ["titre", "perimetre", "quand"])
    #expect(SectionsEssentielles([:]).pour("").isEmpty)
}

@Test func lAPISimuleeEnregistreLeChoixCommeLeServeur() async throws {
    let simule = ServiceSimule(delai: .zero)
    let residence = ServiceSimule.residence
    await #expect(throws: ErreurService.self) { try await simule.choisirSaisie("role", dans: residence) }
    #expect(simule.profilSimule.saisieAffaire == "essentielle")
    try await simule.choisirSaisie("complete", dans: residence)
    #expect(simule.profilSimule.saisieAffaire == "complete")
    let lues = try await simule.referentiels(residence).essentielles
    #expect(lues.pour("panne").contains("mise_en_avant"))
    // Les référentiels simulés servent les sections calculées, pas la seule base.
    #expect(try FixturesReferentielsAffaires.lus().essentielles == lues)
}

@Test func unProfilGardeAvantLaSaisieSeRelit() throws {
    let garde = #"{"statut": "locataire", "roles": ["résident"]}"#
    let profil = try JSONDecoder().decode(ProfilResidence.self, from: Data(garde.utf8))
    #expect(profil.saisieAffaire == nil)
}
