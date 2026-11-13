// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// Le fil d'une affaire (#178) : ses sections, leurs pastilles, leurs résumés pliés, et ce
/// qu'un toucher ouvre — contre l'API simulée, lue comme le serveur la sert.
@MainActor
struct FilAffaireTests {
    private let service = ServiceSimule(delai: .zero)

    @Test func uneAffaireOuverteADemandeSuiteComptesRendusEtSyntheseAVenir() throws {
        let etapes = EtapeFil.du(try service.detailSimule(41))
        #expect(etapes.map(\.cle) == [.demande, .suite, .comptesRendus, .synthese])
        #expect(etapes.map(\.etat) == [.realise, .enCours, .realise, .aVenir])
        let suite = etapes[1]
        #expect(suite.meta == "3 suites", "le nombre d'entrées, jamais « n sur m » : on ne connaît pas la suite")
        #expect(suite.ouverteALaSuite, "le fil d'une affaire ouverte reste ouvert")
        #expect(suite.pliable && etapes[2].pliable)
        #expect(suite.elements.first?.titre == "Ouvert → Chez le syndic")
        #expect(etapes[3].meta == TextesFil.aVenir)
    }

    @Test func laSuitePlieeDitSaDerniereEntree() throws {
        let suite = EtapeFil.du(try service.detailSimule(41))[1]
        let resume = try #require(suite.resumePlie)
        #expect(resume.hasPrefix("9 nov. 2026 — Intervention confirmée à 9 h."), "\(resume)")
    }

    @Test func lesComptesRendusVontDuPlusRecentAuPlusAncien() throws {
        let comptes = EtapeFil.du(try service.detailSimule(41))[2]
        #expect(comptes.elements.map(\.id) == ["cr.7", "cr.5"])
        #expect(comptes.meta == "2 points CS / Syndic")
        #expect(comptes.resumePlie == "Dernier point CS / Syndic le 10 nov. 2026")
        #expect(comptes.elements.first?.ligne == "En salle")
    }

    @Test func uneAffaireCloseLitSaSyntheseEtTaitLaSuiteQuiLaPorte() throws {
        let etapes = EtapeFil.du(try service.detailSimule(31))
        #expect(etapes.map(\.cle) == [.demande, .suite, .comptesRendus, .synthese])
        #expect(etapes[1].etat == .realise && !etapes[1].ouverteALaSuite)
        #expect(etapes[1].elements.map(\.id) == ["suite.4"], "la Suite « synthese » n'est pas une étape")
        let synthese = etapes[3]
        #expect(synthese.etat == .realise && synthese.meta == "Validée le 8 nov. 2026")
        #expect(synthese.elements.map(\.titre) == ["Synthèse", "Difficultés", "Amélioration"])
        #expect(etapes[2].etat == .aVenir && etapes[2].meta == TextesFil.aucunCompteRenduClos)
    }

    @Test func uneAffaireCloseSansSyntheseNEnMontrePas() throws {
        var affaire = try service.detailSimule(31)
        affaire.synthese = nil
        #expect(!EtapeFil.du(affaire).map(\.cle).contains(.synthese))
    }

    @Test func desComptesRendusIllisiblesSeDisent() throws {
        var affaire = try service.detailSimule(41)
        affaire.comptesRendus = nil
        let comptes = EtapeFil.du(affaire)[2]
        #expect(comptes.meta == TextesFil.comptesRendusIllisibles && comptes.elements.isEmpty && !comptes.pliable)
    }

    @Test func uneActualiteNAQueSaDemandeEtSaSuite() throws {
        let etapes = EtapeFil.du(try service.detailSimule(12))
        #expect(etapes.map(\.cle) == [.demande, .suite])
        #expect(etapes[1].etat == .aVenir && etapes[1].meta == TextesFil.aucuneSuite)
    }

    @Test func leRailEstEngageEntreDeuxEtapesEtPointilleAuBoutDUnFilOuvert() {
        let etats: [EtapeFil.Etat] = [.realise, .enCours, .aVenir]
        #expect(TraitDuRail.sous(0, de: etats) == .engage)
        #expect(TraitDuRail.sous(1, de: etats) == .discret)
        #expect(TraitDuRail.sous(2, de: etats) == nil)
        #expect(TraitDuRail.sous(2, de: etats, ouvert: true) == .pointille)
    }

    @Test func unToucherOuvreUnInstantPuisLeFilSeReplie() async throws {
        let depliage = DepliageDuFil(duree: .milliseconds(50))
        depliage.toucher("suite.1")
        #expect(depliage.estOuvert("suite.1") && !depliage.estGarde("suite.1"))
        depliage.toucher("suite.2")
        #expect(!depliage.estOuvert("suite.1") && depliage.estOuvert("suite.2"), "un seul à la fois")
        try await Task.sleep(for: .milliseconds(300))
        #expect(!depliage.estOuvert("suite.2"), "replié seul après le regard")
    }

    @Test func gardeOuvertResisteAuToucherEtALaMinuterie() async throws {
        let depliage = DepliageDuFil(duree: .milliseconds(50))
        depliage.toucher("cr.7")
        depliage.basculerGarde("cr.7")
        try await Task.sleep(for: .milliseconds(300))
        depliage.toucher("cr.7")
        #expect(depliage.estOuvert("cr.7") && depliage.estGarde("cr.7"))
        depliage.basculerGarde("cr.7")
        #expect(!depliage.estOuvert("cr.7"), "relâché, il se replie")
    }

    @Test func lesComptesRendusPartentPlies() {
        let depliage = DepliageDuFil()
        #expect(depliage.estPliee(.comptesRendus) && !depliage.estPliee(.suite))
        depliage.basculerPli(.suite)
        #expect(depliage.estPliee(.suite))
    }
}
