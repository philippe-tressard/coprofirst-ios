// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

/// Le bandeau d'une affaire : les icônes suivent les droits SERVIS, dans l'ordre du site.
@MainActor
struct BandeauAffaireTests {
    private func affaire(
        _ droits: DroitsServisAffaire, categorie: String = "plomberie", archivee: Bool = false,
        fusionnee: Bool = false
    ) -> DetailAffaire {
        DetailAffaire(
            id: 41, numero: "A-0041", titre: "T", description: "", categorie: categorie, statut: "en_cours",
            urgente: false, creeLe: .now, auteur: nil, lieu: nil, suites: [], droits: droits,
            archivee: archivee, fusionnee: fusionnee, referentiels: (try? FixturesReferentielsAffaires.lus()) ?? .vides)
    }

    private let tout = DroitsServisAffaire(
        repondre: true, changerEtat: true, modifier: true, archiver: true, corriger: true)

    @Test func leConseilSuitLAffaireSansRepondre() {
        #expect(
            GesteAffaire.offerts(pour: affaire(tout), conseil: true) == [.lien, .suite, .modifier, .options, .archiver])
    }

    @Test func unResidentRepondQuandLaRouteLAccepte() {
        #expect(GesteAffaire.offerts(pour: affaire(.init(repondre: true)), conseil: false) == [.lien, .repondre])
        #expect(
            GesteAffaire.offerts(pour: affaire(.init()), conseil: false) == [.lien], "aucun droit servi : le lien seul")
    }

    @Test func niActualiteNiFusionneeNiArchiveeNOffrentLeursGestes() {
        let actualite = affaire(.init(repondre: true), categorie: "actualite")
        #expect(!GesteAffaire.offerts(pour: actualite, conseil: false).contains(.repondre))
        let fusionnee = affaire(.init(repondre: true), fusionnee: true)
        #expect(!GesteAffaire.offerts(pour: fusionnee, conseil: false).contains(.repondre))
        #expect(!GesteAffaire.offerts(pour: affaire(tout, archivee: true), conseil: true).contains(.archiver))
    }

    @Test func lesDroitsSeLisentDansLAffaireServie() throws {
        let json = #"""
            {"id": 41, "numero": "A-0041", "titre": "T", "description": "", "categorie": "plomberie",
             "categorie_libelle": "Plomberie", "statut": "en_cours", "statut_libelle": "Chez le syndic",
             "close": false, "colonne_kanban": "en_cours", "cree_le": "2026-11-01T10:00:00",
             "nom_proprietaire": "", "nouveau": false, "priorite": "normale", "urgente": false,
             "peut_repondre": true, "peut_archiver": true, "epingle": true,
             "frequence_libelle": "", "suivi_actualite_libelle": ""}
            """#
        let lu = DetailAffaire(
            ticket: try Relecture.generee(Components.Schemas.TicketRead.self, json: json), suites: [])
        #expect(lu.droits == DroitsServisAffaire(repondre: true, archiver: true), "un champ absent vaut « non »")
        #expect(lu.epingle && !lu.archivee)
    }

    @Test func uneSuiteQuiGardeLEtatEstUnCommentaireRequis() {
        var saisie = SaisieSuite(affaire: affaire(tout))
        #expect(!saisie.prete && saisie.type == "commentaire")
        saisie.contenu = "  Le plombier est passé.  "
        #expect(saisie.prete && saisie.texte == "Le plombier est passé.")
        saisie.contenu = ""
        saisie.statut = "résolu"
        #expect(saisie.prete && saisie.type == "etat", "un nouvel état suffit")
        // Les états SERVIS proposables (#105) : le cycle, sans `fermé` ni `publie`.
        #expect(
            SaisieSuite.etats(pour: affaire(tout)).map(\.code)
                == ["ouvert", "en_ag", "en_cours", "chez_prestataire", "résolu", "annulé"])
        #expect(SaisieSuite.etats(pour: affaire(tout)).first { $0.code == "en_cours" }?.libelle == "Chez le syndic")
        #expect(SaisieSuite.etats(pour: affaire(tout, categorie: "actualite")).isEmpty)
    }

    @Test func lesOptionsSontCellesDuSite() {
        #expect(OptionAffaire.toutes.map(\.cle) == ["epingle", "urgente"])
    }

    @Test func unTexteSaisiSEcritCommeLEditeurDuSite() {
        #expect(TexteDuSite.html(saisi: "a < b\nc\n\n  d  ") == "<p>a &lt; b<br>c</p><p>d</p>")
    }

    @Test func lesGestesSimulesChangentLAffaire() async throws {
        let service = ServiceSimule(delai: .zero)
        let residence = ServiceSimule.residence
        var saisie = SaisieSuite(affaire: try service.detailSimule(41))
        saisie.statut = "résolu"
        try await service.ajouterSuite(saisie, a: 41, dans: residence)
        try await service.archiverAffaire(41, dans: residence)
        let apres = try service.detailSimule(41)
        #expect(apres.statut == "résolu" && apres.archivee)
        #expect(apres.suites.last?.changementDEtat(apres.referentiels) == "Chez le syndic → Résolu")
        #expect(apres.statutLibelle == "Résolu", "le libellé suit l'état, servi")
    }
}
