// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// Une correction du Suivi que l'affaire n'a pas suivie (#187, coprofirst#2715) : la
/// réponse le dit (`affaire_suivie`, `affaire_suivie_libelle`, `etat_propose`, contrat
/// 1.30.0, au-dessus du plancher). L'app montre la phrase servie et propose l'état servi,
/// selon le droit servi — rien de composé ; rien de servi, rien de plus qu'avant.
@MainActor
struct IssueCorrectionTests {
    private let residence = ServiceSimule.residence

    /// Une entrée corrigée telle que servie, avec `extra` ajouté au JSON.
    private func corps(_ extra: String) -> Data {
        Data(
            (#"""
            {"id": 1, "ticket_id": 41, "type": "etat", "cree_le": "2026-11-09T10:00:00",
             "nouveau_statut_libelle": "", "perimetre_precise_libelle": ""
            """# + extra + "}").utf8)
    }

    private func affaire(changerEtat: Bool = true) throws -> DetailAffaire {
        var affaire = DetailAffaire(
            id: 41, numero: "A-0041", titre: "T", description: "", categorie: "sinistre", statut: "résolu",
            urgente: false, creeLe: .now, auteur: nil, lieu: nil, suites: [])
        affaire.droits.changerEtat = changerEtat
        affaire.referentiels = try FixturesReferentielsAffaires.lus(moderateur: true)
        return affaire
    }

    private func conseil() -> ServiceSimule { ServiceSimule(delai: .zero) }

    // MARK: - La lecture : la réponse, telle que servie

    @Test func laFixtureSeLitTelleQueServie() throws {
        let issue = try #require(IssueCorrection.lue(corps: Data(FixturesCorrectionSuite.nonSuivie.utf8)))
        #expect(issue.phrase.hasPrefix("L'affaire est restée « Résolu »"))
        #expect(issue.etatPropose == "chez_prestataire" && issue.etatProposeLibelle == "Chez le prestataire")
    }

    /// Une installation antérieure au contrat 1.30.0 ne sert rien : rien de plus qu'avant.
    @Test func rienDeServiNeDitRien() {
        #expect(IssueCorrection.lue(corps: corps("")) == nil, "installation antérieure")
        #expect(IssueCorrection.lue(corps: nil) == nil)
        #expect(IssueCorrection.lue(corps: Data("<html>".utf8)) == nil, "illisible : défaut fermé")
    }

    @Test func uneAffaireQuiASuiviNeDitRien() {
        #expect(IssueCorrection.lue(corps: corps(#", "affaire_suivie": true, "affaire_suivie_libelle": """#)) == nil)
        #expect(IssueCorrection.lue(corps: corps(#", "affaire_suivie": null, "affaire_suivie_libelle": """#)) == nil)
    }

    /// Sans phrase servie, l'app n'en compose pas.
    @Test func sansPhraseServieRienNeSeDit() {
        let muette = corps(#", "affaire_suivie": false, "affaire_suivie_libelle": "", "etat_propose": "ouvert""#)
        #expect(IssueCorrection.lue(corps: muette) == nil)
    }

    // MARK: - La proposition : l'état servi, selon le droit servi

    @Test func lEtatProposeSOffreAQuiPeutChangerLEtat() throws {
        let issue = try #require(IssueCorrection.lue(corps: Data(FixturesCorrectionSuite.nonSuivie.utf8)))
        let saisie = try #require(issue.proposition(pour: try affaire()))
        #expect(saisie.statut == "chez_prestataire" && saisie.changeEtat && saisie.type == "etat")
        #expect(issue.libelleProposition(pour: try affaire()) == "Appliquer « Chez le prestataire » à l’affaire")
        #expect(issue.proposition(pour: try affaire(changerEtat: false)) == nil, "droit non servi : aucun geste")
        #expect(issue.libelleProposition(pour: try affaire(changerEtat: false)) == nil)
    }

    /// Le libellé servi d'abord ; à défaut, celui des référentiels servis.
    @Test func lEtatProposeSeDitEnClair() throws {
        let sansLibelle = IssueCorrection(phrase: "P", etatPropose: "ouvert", etatProposeLibelle: nil)
        #expect(sansLibelle.libelleProposition(pour: try affaire()) == "Appliquer « Ouvert » à l’affaire")
    }

    /// Le suivi d'une actualité : le serveur ne propose rien, la phrase seule se dit.
    @Test func sansEtatProposeLaPhraseSeule() throws {
        let servi = corps(#", "affaire_suivie": false, "affaire_suivie_libelle": "Restée.", "etat_propose": null"#)
        let issue = try #require(IssueCorrection.lue(corps: servi))
        let servie = try affaire()
        #expect(issue.phrase == "Restée." && issue.proposition(pour: servie) == nil)
    }

    @Test func lEtatOuEstDejaLAffaireNeSePropose() throws {
        let issue = IssueCorrection(phrase: "P", etatPropose: "résolu", etatProposeLibelle: "Résolu")
        #expect(issue.proposition(pour: try affaire()) == nil)
    }

    // MARK: - Le service réel relit la réponse du PATCH

    @Test func leServiceReelRendCeQueLaReponseDit() async throws {
        let servi = FixturesCorrectionSuite.nonSuivie
        let issue = try await ServiceAPI(transport: { _ in TransportFixe(corps: servi) })
            .corrigerSuite(CorrectionSuite(suivi: .init(type: "etat", statut: "chez_prestataire")), 1, de: 41,
                           dans: residence)
        #expect(issue?.etatPropose == "chez_prestataire")
        let anterieure = try #require(String(bytes: corps(""), encoding: .utf8))
        let rien = try await ServiceAPI(transport: { _ in TransportFixe(corps: anterieure) })
            .corrigerSuite(CorrectionSuite(contenuHTML: "<p>Un mot.</p>"), 1, de: 41, dans: residence)
        #expect(rien == nil, "une installation antérieure : rien de plus")
    }

    // MARK: - Le faux serveur : la règle de coprofirst#2715

    /// Une Suite plus récente a changé l'état : corriger la première ne l'écrase pas, la
    /// réponse le dit et propose l'état ; l'appliquer passe par une Suite.
    @Test func uneTransitionPlusRecenteNeSEcrasePas() async throws {
        let service = conseil()
        var resolu = SaisieSuite(affaire: try service.detailSimule(41))
        resolu.statut = "résolu"
        try await service.ajouterSuite(resolu, a: 41, dans: residence)

        let issue = try #require(
            try await service.corrigerSuite(
                CorrectionSuite(suivi: .init(type: "etat", statut: "chez_prestataire")), 1, de: 41, dans: residence))
        var apres = try service.detailSimule(41)
        #expect(apres.statut == "résolu", "rien n'est écrasé")
        #expect(apres.suites.first?.nouveauStatut == "chez_prestataire", "l'entrée est corrigée")
        #expect(issue.phrase == "L'affaire est restée « Résolu » : une Suite plus récente a changé son état depuis.")
        #expect(issue.etatPropose == "chez_prestataire")

        try await service.ajouterSuite(try #require(issue.proposition(pour: apres)), a: 41, dans: residence)
        apres = try service.detailSimule(41)
        #expect(apres.statut == "chez_prestataire" && apres.suites.last?.type == "etat")
    }

    /// La dernière transition : l'affaire suit, rien à dire.
    @Test func laDerniereTransitionSuitSansRienDire() async throws {
        let service = conseil()
        let issue = try await service.corrigerSuite(
            CorrectionSuite(suivi: .init(type: "etat", statut: "chez_prestataire")), 1, de: 41, dans: residence)
        #expect(issue == nil)
        #expect(try service.detailSimule(41).statut == "chez_prestataire")
    }

    /// Le texte seul : le Suivi ne change pas, rien à dire.
    @Test func leTexteSeulNeDitRien() async throws {
        let service = conseil()
        var resolu = SaisieSuite(affaire: try service.detailSimule(41))
        resolu.statut = "résolu"
        try await service.ajouterSuite(resolu, a: 41, dans: residence)
        let issue = try await service.corrigerSuite(CorrectionSuite(contenuHTML: "<p>Un mot.</p>"), 1, de: 41,
                                                    dans: residence)
        #expect(issue == nil)
    }
}
