// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// L'entrée de l'écran de hall (#218, lot 2) : l'adresse saisie ou la démo, GET /config au
/// plancher, les phrases de l'iPhone. Aucun réseau : la découverte est simulée ici.
private actor DecouverteSimulee: DecouvreInstallation {
    private(set) var demandees: [URL] = []
    private let reponses: [String: Result<Installation, ErreurService>]

    init(_ reponses: [String: Result<Installation, ErreurService>]) {
        self.reponses = reponses
    }

    func decouvrir(_ adresse: URL) async throws -> Installation {
        demandees.append(adresse)
        guard let reponse = reponses[adresse.host() ?? ""] else { throw ErreurService.injoignable }
        return try reponse.get()
    }
}

/// Une résidence au plancher : le contrat se lit sur `VersionContrat.plancher` (généré), jamais
/// en dur — une valeur écrite ici tombait sous le plancher à sa montée (2.6.0 sous 2.8.0, #294).
private func residence(
    _ hote: String, contrat: String? = VersionContrat.plancher.description, palette: String? = "prune"
) -> Installation {
    Installation(
        adresse: URL(string: "https://\(hote)")!, nom: "Les Tilleuls", aUnLogo: false,
        codePalette: palette, versionContrat: contrat)
}

@MainActor
@Test func uneAdresseSaisieOuvreSaResidence() async {
    let service = DecouverteSimulee(["tilleuls.example.com": .success(residence("tilleuls.example.com"))])
    let entree = EntreeTV(service: service)
    entree.saisie = "  HTTP://Tilleuls.example.com/connexion "
    #expect(entree.adresseSaisie == URL(string: "https://tilleuls.example.com"), "ramenée à https://<hôte>")
    await entree.entrer()
    #expect(entree.residence?.nom == "Les Tilleuls")
    #expect(entree.residence?.palette.code == "prune", "la palette de la résidence")
    #expect(entree.decouverte.erreur == nil)
    #expect(await service.demandees == [URL(string: "https://tilleuls.example.com")!])
}

@MainActor
@Test func uneSaisieQuiNEstPasUneAdresseNeDemandeRien() async {
    let service = DecouverteSimulee([:])
    let entree = EntreeTV(service: service)
    for saisie in ["", "pas une adresse", "localhost"] {
        entree.saisie = saisie
        #expect(entree.adresseSaisie == nil, "« \(saisie) » : Continuer reste grisé")
        await entree.entrer()
    }
    #expect(await service.demandees.isEmpty)
    #expect(entree.residence == nil)
}

@MainActor
@Test func laDemoEstCelleEcriteDansLApp() async {
    let hote = ContenuVitrine.adresseDemo
    let service = DecouverteSimulee([hote: .success(residence(hote))])
    let entree = EntreeTV(service: service)
    await entree.entrerEnDemo()
    #expect(await service.demandees == [URL(string: "https://\(hote)")!])
    #expect(entree.residence?.adresse.host() == hote)
}

@MainActor
@Test func unEchecDitLaPhraseDeLIPhone() async {
    let service = DecouverteSimulee(["vide.example.com": .failure(.hoteInconnu)])
    let entree = EntreeTV(service: service)
    entree.saisie = "vide.example.com"
    await entree.entrer()
    #expect(entree.residence == nil)
    #expect(entree.decouverte.erreur == .hoteInconnu)
    entree.saisie = "muette.example.com"
    await entree.entrer()
    #expect(entree.decouverte.erreur == .injoignable)
}

/// Une installation qui sert un contrat sous le plancher ne s'ouvre pas, comme sur l'iPhone (#83).
@MainActor
@Test func uneResidenceSousLePlancherNeSOuvrePas() async {
    let service = DecouverteSimulee(["ancienne.example.com": .success(residence("ancienne.example.com", contrat: "1.0.0"))])
    let entree = EntreeTV(service: service)
    entree.saisie = "ancienne.example.com"
    await entree.entrer()
    #expect(entree.residence == nil)
    #expect(entree.decouverte.erreur == .residenceAMettreAJour)
}

@MainActor
@Test func changerDeResidenceRevientALaSaisiePreRemplie() async {
    let service = DecouverteSimulee(["tilleuls.example.com": .success(residence("tilleuls.example.com"))])
    let entree = EntreeTV(service: service)
    entree.saisie = "https://tilleuls.example.com"
    await entree.entrer()
    entree.changer()
    #expect(entree.residence == nil)
    #expect(entree.saisie == "tilleuls.example.com")
    #expect(entree.decouverte.erreur == nil)
}
