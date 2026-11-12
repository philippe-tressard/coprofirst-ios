// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

// Le PLANCHER à la découverte (#83) : une installation qui sert un contrat plus ancien
// que celui sur lequel l'app se génère le dit, au lieu de « La résidence n'a pas pu
// répondre » à chaque écran.

private func installation(contrat: String?) -> Installation {
    Installation(
        adresse: URL(string: "https://residence.exemple.fr")!, nom: "Résidence", aUnLogo: false,
        versionContrat: contrat)
}

@Test func sousLePlancherLaResidenceDoitEtreMiseAJour() {
    #expect(throws: ErreurService.residenceAMettreAJour) { try installation(contrat: "1.12.0").exigerLePlancher() }
    #expect(throws: ErreurService.residenceAMettreAJour) { try installation(contrat: "0.9").exigerLePlancher() }
}

@Test func auPlancherOuAuDessusLaResidenceSOuvre() throws {
    try installation(contrat: VersionContrat.plancher.description).exigerLePlancher()
    try installation(contrat: "1.28.0").exigerLePlancher()
    try installation(contrat: "2.0.0").exigerLePlancher()
}

@Test func uneVersionAbsenteOuIllisibleNeBloquePas() throws {
    // L'app ne devine pas une version : sans elle, la découverte ne refuse rien.
    try installation(contrat: nil).exigerLePlancher()
    try installation(contrat: "1.x").exigerLePlancher()
}

@Test func laPhraseDitLaMiseAJourPasUnePanne() {
    let phrase = ErreurService.residenceAMettreAJour.phrase
    #expect(phrase.contains("doit être mise à jour"))
    #expect(phrase != ErreurService.inattendue(0).phrase)
}

@MainActor
@Test func laDecouverteDUneResidenceSousLePlancherLeDit() async {
    let decouverte = EtatDecouverte()
    let service = ServiceSimule(delai: .zero)
    let ancienne = await decouverte.decouvrir(URL(string: "https://ancienne.exemple.fr")!, avec: service)
    #expect(ancienne == nil)
    #expect(decouverte.erreur == .residenceAMettreAJour)
    let recente = await decouverte.decouvrir(URL(string: "https://tilleuls.exemple.fr")!, avec: service)
    #expect(recente != nil && decouverte.erreur == nil)
}

@Test func lesResidencesSimuleesSontAuDessusDuPlancher() throws {
    // Sinon les aperçus et les tests d'interface s'arrêteraient à la découverte.
    try ServiceSimule.residence.exigerLePlancher()
    try ServiceSimule.demo.exigerLePlancher()
}
