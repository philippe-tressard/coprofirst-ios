// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

@Test(arguments: [
    ("demo.coprofirst.fr", "https://demo.coprofirst.fr"),
    ("  Demo.CoproFirst.fr  ", "https://demo.coprofirst.fr"),
    ("https://demo.coprofirst.fr/auth/connexion?x=1", "https://demo.coprofirst.fr"),
    ("http://demo.coprofirst.fr", "https://demo.coprofirst.fr"),
    ("residence.exemple.fr:8443", "https://residence.exemple.fr:8443"),
])
func uneAdresseSeRameneAuSite(saisie: String, attendu: String) {
    #expect(AdresseInstallation.normaliser(saisie)?.absoluteString == attendu)
}

@Test(arguments: ["", "   ", "localhost", "pas une adresse", ".fr", "demo.", "ftp://"])
func uneSaisieQuiNEstPasUneAdresseEstRefusee(saisie: String) {
    #expect(AdresseInstallation.normaliser(saisie) == nil)
}

@Test func chaqueStatutDitUnePhraseJamaisUnCode() {
    #expect(ErreurService.depuis(statut: 421) == .hoteInconnu)
    #expect(ErreurService.depuis(statut: 401) == .identifiantsRefuses)
    #expect(ErreurService.depuis(statut: 429) == .tropDEssais)
    #expect(ErreurService.depuis(statut: 503) == .inattendue(503))
    for erreur in [ErreurService.hoteInconnu, .injoignable, .horsLigne, .inattendue(503)] {
        #expect(!erreur.phrase.contains { $0.isNumber }, "« \(erreur.phrase) » montre un code")
    }
}

@Test func uneErreurReseauDitInjoignableOuHorsLigne() {
    #expect(ErreurService.depuis(URLError(.cannotFindHost)) == .injoignable)
    #expect(ErreurService.depuis(URLError(.timedOut)) == .injoignable)
    #expect(ErreurService.depuis(URLError(.notConnectedToInternet)) == .horsLigne)
}
