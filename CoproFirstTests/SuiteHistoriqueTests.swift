// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

/// Corriger et effacer une Suite depuis l'Historique (#91, #93) : les gestes d'une
/// entrée sont ceux que le serveur sert AVEC elle (`peut_modifier`, `peut_supprimer`,
/// typés au plancher) — absents, aucun geste ; la correction n'envoie que ce qui a changé.
@MainActor
struct SuiteHistoriqueTests {
    private let residence = ServiceSimule.residence

    /// Une affaire servie.
    private let ticket = #"""
        {"id": 41, "numero": "A-0041", "titre": "T", "description": "", "categorie": "plomberie",
         "categorie_libelle": "Plomberie", "statut": "en_cours", "statut_libelle": "Chez le syndic",
         "close": false, "colonne_kanban": "en_cours", "cree_le": "2026-11-01T10:00:00",
         "nom_proprietaire": "", "nouveau": false, "priorite": "normale", "urgente": false,
         "suivi_actualite_libelle": "", "frequence_libelle": ""}
        """#

    /// Trois entrées servies à un administrateur : un changement d'état et un commentaire,
    /// qu'il corrige et efface ; une réponse, qui appartient à son auteur.
    private let servies = #"""
        [{"id": 1, "ticket_id": 41, "type": "etat",
           "nouveau_statut_libelle": "", "perimetre_precise_libelle": "", "cree_le": "2026-11-09T10:00:00",
          "ancien_statut": "ouvert", "nouveau_statut": "en_cours", "peut_modifier": true, "peut_supprimer": true},
         {"id": 2, "ticket_id": 41, "type": "commentaire",
           "nouveau_statut_libelle": "", "perimetre_precise_libelle": "", "cree_le": "2026-11-09T11:00:00",
          "contenu": "Un mot.", "statut_avant": "en_cours", "peut_modifier": true, "peut_supprimer": true},
         {"id": 3, "ticket_id": 41, "type": "reponse",
           "nouveau_statut_libelle": "", "perimetre_precise_libelle": "", "cree_le": "2026-11-09T13:00:00",
          "contenu": "Une réponse.", "peut_modifier": false, "peut_supprimer": false}]
        """#

    /// L'Historique lu par LA relecture du détail (`DetailAffaire.lue`), comme le service
    /// réel le lit : par le type généré.
    private func lues(_ json: String) throws -> [SuiteAffaire] {
        let lu = try Relecture.generee(Components.Schemas.TicketRead.self, json: ticket)
        let evolutions = try Relecture.generee([Components.Schemas.TicketEvolutionRead].self, json: json)
        return DetailAffaire.lue(lu, evolutions: evolutions).suites
    }

    private func entree(
        _ type: String, contenu: String? = nil, avant: String? = "en_cours", nouveau: String? = nil
    ) -> SuiteAffaire {
        SuiteAffaire(
            id: 7, type: type, date: .now, auteur: nil, contenu: contenu, ancienStatut: avant,
            nouveauStatut: nouveau)
    }

    private var affaire: DetailAffaire {
        DetailAffaire(
            id: 41, numero: "A-0041", titre: "T", description: "", categorie: "sinistre", statut: "résolu",
            urgente: false, creeLe: .now, auteur: nil, lieu: nil, suites: [])
    }

    private func service(_ compte: String = "conseil") -> ServiceSimule {
        let service = ServiceSimule(delai: .zero)
        switch compte {
        case "administrateur": service.profilSimule.roles.append("admin")
        // Comme `-compte resident` (`LancementSimule`) : `est_moderateur` servi à faux.
        case "resident":
            service.profilSimule.roles.removeAll { $0 == "conseil_syndical" }
            service.profilSimule.estModerateur = false
        default: break
        }
        return service
    }

    // MARK: - #93 : les gestes d'une entrée se lisent tels que servis

    @Test func lesGestesDUneEntreeSeLisentTelsQueServis() throws {
        let servies = try lues(servies)
        let tout = DroitsServisSuite(modifier: true, supprimer: true)
        #expect(servies.map(\.droits) == [tout, tout, DroitsServisSuite()], "une réponse appartient à son auteur")
        #expect(servies.map(GesteSuite.offerts) == [[.modifier, .supprimer], [.modifier, .supprimer], []])
    }

    @Test func unSeulGesteServiNOffreQueLui() throws {
        let json = #"""
            [{"id": 1, "ticket_id": 41, "type": "commentaire",
              "nouveau_statut_libelle": "", "perimetre_precise_libelle": "", "cree_le": "2026-11-09T11:00:00",
              "contenu": "Un mot.", "peut_modifier": true, "peut_supprimer": false},
             {"id": 2, "ticket_id": 41, "type": "commentaire",
              "nouveau_statut_libelle": "", "perimetre_precise_libelle": "", "cree_le": "2026-11-09T12:00:00",
              "contenu": "Un autre.", "peut_modifier": null}]
            """#
        let servies = try lues(json)
        #expect(servies.map(GesteSuite.offerts) == [[.modifier], []], "le conseil corrige, l'administrateur efface")
    }

    /// Le défaut FERMÉ : une entrée servie sans ces champs (ils sont facultatifs au
    /// contrat) se lit sans geste, comme avant.
    @Test func desGestesAbsentsNOuvrentRien() throws {
        let json = #"""
            [{"id": 1, "ticket_id": 41, "type": "commentaire",
              "nouveau_statut_libelle": "", "perimetre_precise_libelle": "", "cree_le": "2026-11-09T11:00:00",
              "contenu": "Un mot.", "statut_avant": "en_cours"}]
            """#
        #expect(try lues(json).map(GesteSuite.offerts) == [[]])
        #expect(try lues(json).first?.ancienStatut == "en_cours", "l'état d'avant, lui, est au plancher")
    }

    // MARK: - #91 : la correction part de l'entrée, et n'envoie que ce qui a changé

    @Test func laCorrectionPartDeLEntreeServie() {
        let commentaire = entree("commentaire", contenu: "<p>Le syndic est prévenu.</p>")
        let saisie = SaisieSuite(corrigeant: commentaire, de: affaire)
        #expect(saisie.statutActuel == "en_cours" && saisie.statut == "en_cours", "l'état d'AVANT l'entrée")
        #expect(saisie.contenu == "Le syndic est prévenu." && !saisie.changeEtat)
        #expect(
            saisie.correction(depuis: commentaire, de: affaire).vide && !saisie.prete(depuis: commentaire, de: affaire))

        let transition = entree("etat", avant: "ouvert", nouveau: "en_cours")
        let suivi = SaisieSuite(corrigeant: transition, de: affaire)
        #expect(suivi.statutActuel == "ouvert" && suivi.statut == "en_cours" && suivi.changeEtat)
        #expect(suivi.correction(depuis: transition, de: affaire).vide)

        let sansAvant = SaisieSuite(corrigeant: entree("commentaire", contenu: "Un mot.", avant: nil), de: affaire)
        #expect(sansAvant.statutActuel == "résolu", "à défaut d'état servi, celui de l'affaire")
    }

    @Test func seulCeQuiAChangePart() {
        let commentaire = entree("commentaire", contenu: "<p>Le syndic est prévenu.</p>")
        var saisie = SaisieSuite(corrigeant: commentaire, de: affaire)
        saisie.contenu = "Le syndic est prévenu.\nIl rappelle demain."
        #expect(
            saisie.correction(depuis: commentaire, de: affaire)
                == CorrectionSuite(contenuHTML: "<p>Le syndic est prévenu.<br>Il rappelle demain.</p>"))
        #expect(saisie.prete(depuis: commentaire, de: affaire))

        saisie = SaisieSuite(corrigeant: commentaire, de: affaire)
        saisie.statut = "résolu"
        #expect(
            saisie.correction(depuis: commentaire, de: affaire)
                == CorrectionSuite(suivi: .init(type: "etat", statut: "résolu")),
            "un commentaire devient une transition")

        saisie.contenu = "   "
        #expect(saisie.correction(depuis: commentaire, de: affaire).contenuHTML?.isEmpty == true, "le texte retiré")
    }

    @Test func revenirALEtatDAvantRefaitUnCommentaire() {
        let transition = entree("etat", contenu: "<p>Le plombier est passé.</p>", avant: "ouvert", nouveau: "en_cours")
        var saisie = SaisieSuite(corrigeant: transition, de: affaire)
        saisie.statut = "ouvert"
        #expect(
            saisie.correction(depuis: transition, de: affaire)
                == CorrectionSuite(suivi: .init(type: "commentaire", statut: nil)))
        #expect(saisie.prete(depuis: transition, de: affaire), "elle garde son texte")

        let muette = entree("etat", avant: "ouvert", nouveau: "en_cours")
        saisie = SaisieSuite(corrigeant: muette, de: affaire)
        saisie.statut = "ouvert"
        #expect(!saisie.prete(depuis: muette, de: affaire), "un commentaire sans texte ne part pas")
    }

    @Test func unTexteMisEnFormeNeSeReecritPas() {
        let riche = entree("commentaire", contenu: "<p>Le plombier passe <strong>demain matin</strong>.</p>")
        #expect(riche.contenuSaisi == nil)
        var saisie = SaisieSuite(corrigeant: riche, de: affaire)
        saisie.contenu = "Tout autre chose."
        #expect(
            saisie.correction(depuis: riche, de: affaire).vide, "le texte que la feuille ne sait pas réécrire reste")
        saisie.statut = "résolu"
        #expect(
            saisie.correction(depuis: riche, de: affaire)
                == CorrectionSuite(suivi: .init(type: "etat", statut: "résolu")))
        #expect(saisie.prete(depuis: riche, de: affaire))
    }

    @Test func unEtatQueLaListeNeDitPasNeSeCorrigePas() {
        let etats = ["ouvert", "en_cours", "résolu"]
        #expect(SaisieSuite(corrigeant: entree("commentaire"), de: affaire).suiviCorrigeable(parmi: etats))
        let hors = entree("etat", avant: "ouvert", nouveau: "état_inconnu")
        #expect(!SaisieSuite(corrigeant: hors, de: affaire).suiviCorrigeable(parmi: etats))
        #expect(!SaisieSuite(corrigeant: entree("commentaire"), de: affaire).suiviCorrigeable(parmi: []))
    }

    /// Le corps du PATCH : les seuls champs changés — le serveur ne touche pas aux autres.
    @Test func leCorpsDeLaCorrectionNePorteQueCeQuiChange() throws {
        func cles(_ correction: CorrectionSuite) throws -> [String: String] {
            let corps = try JSONEncoder().encode(ServiceAPI.corpsCorrection(correction))
            let objet = try #require(try JSONSerialization.jsonObject(with: corps) as? [String: Any])
            return objet.mapValues { "\($0)" }
        }
        #expect(try cles(CorrectionSuite(contenuHTML: "<p>Un mot.</p>")) == ["contenu": "<p>Un mot.</p>"])
        #expect(
            try cles(CorrectionSuite(suivi: .init(type: "etat", statut: "résolu")))
                == ["type": "etat", "nouveau_statut": "résolu"])
        #expect(try cles(CorrectionSuite(suivi: .init(type: "commentaire", statut: nil))) == ["type": "commentaire"])
        #expect(throws: ErreurService.self) {
            try ServiceAPI.corpsCorrection(CorrectionSuite(suivi: .init(type: "etat", statut: "état_inconnu")))
        }
    }

    // MARK: - L'API simulée sert et applique comme le serveur

    @Test func leFauxServeurSertLesGestesSelonLeCompte() throws {
        let corrige = DroitsServisSuite(modifier: true)
        #expect(try service().detailSimule(41).suites.map(\.droits) == [corrige, corrige, DroitsServisSuite()])
        let tout = DroitsServisSuite(modifier: true, supprimer: true)
        #expect(
            try service("administrateur").detailSimule(41).suites.map(\.droits) == [tout, tout, DroitsServisSuite()])
        #expect(try service("resident").detailSimule(41).suites.allSatisfy { $0.droits == DroitsServisSuite() })
    }

    /// La fixture sert l'Historique à un résident, par LA relecture du détail : les champs y
    /// sont servis (le juge des fixtures les exige déclarés), et tous fermés.
    @Test func laFixtureServieAUnResidentNOuvreAucunGeste() throws {
        let suites = try #require(try FixturesDetailAffaire.lue(41)).suites
        #expect(suites.count == 3 && suites.allSatisfy { GesteSuite.offerts(pour: $0).isEmpty })
        #expect(suites.map(\.ancienStatut) == ["ouvert", "en_cours", "en_cours"], "l'état d'avant chaque entrée")
    }

    @Test func uneSuiteDuCompteSeCorrigeEtNeSEffacePas() async throws {
        let conseil = service()
        var saisie = SaisieSuite(affaire: try conseil.detailSimule(38))
        saisie.contenu = "Le devis est arrivé."
        try await conseil.ajouterSuite(saisie, a: 38, dans: residence)
        let ajoutee = try #require(try conseil.detailSimule(38).suites.last)
        #expect(GesteSuite.offerts(pour: ajoutee) == [.modifier], "effacer est à l'administrateur")

        var correction = SaisieSuite(corrigeant: ajoutee, de: try conseil.detailSimule(38))
        #expect(correction.contenu == "Le devis est arrivé.")
        correction.contenu = "Le devis est arrivé jeudi."
        try await conseil.corrigerSuite(
            correction.correction(depuis: ajoutee, de: try conseil.detailSimule(38)), ajoutee.id, de: 38,
            dans: residence)
        let corrigee = try #require(try conseil.detailSimule(38).suites.last)
        #expect(corrigee.contenu == "<p>Le devis est arrivé jeudi.</p>")
        #expect(corrigee.id == ajoutee.id && corrigee.date == ajoutee.date, "l'entrée garde sa date")
    }

    /// Le Suivi de la DERNIÈRE transition : l'affaire suit la correction (`suivi_fil.py`).
    @Test func corrigerLeSuiviFaitSuivreLAffaire() async throws {
        let admin = service("administrateur")
        let avant = try admin.detailSimule(41)
        let transition = try #require(avant.suites.first)
        #expect(transition.changementDEtat(avant.referentiels) == "Ouvert → Chez le syndic")
        try await admin.corrigerSuite(
            CorrectionSuite(suivi: .init(type: "etat", statut: "résolu")), transition.id, de: 41, dans: residence)
        var apres = try admin.detailSimule(41)
        #expect(apres.suites.first?.changementDEtat(apres.referentiels) == "Ouvert → Résolu")
        #expect(apres.statut == "résolu")

        try await admin.corrigerSuite(
            CorrectionSuite(suivi: .init(type: "commentaire", statut: nil)), transition.id, de: 41, dans: residence)
        apres = try admin.detailSimule(41)
        #expect(
            apres.suites.first?.type == "commentaire" && apres.suites.first?.changementDEtat(apres.referentiels) == nil)
        #expect(apres.statut == "ouvert", "revenue à l'état d'avant l'entrée")
    }

    @Test func effacerUneEntreeNeChangePasLEtat() async throws {
        let admin = service("administrateur")
        try await admin.supprimerSuite(1, de: 41, dans: residence)
        let apres = try admin.detailSimule(41)
        #expect(apres.suites.map(\.id) == [2, 3] && apres.statut == "en_cours")
    }

    @Test func leFauxServeurRefuseCeQuIlNAPasServi() async throws {
        let conseil = service()
        await #expect(throws: ErreurService.self) { try await conseil.supprimerSuite(1, de: 41, dans: residence) }
        let correction = CorrectionSuite(contenuHTML: "<p>Un mot.</p>")
        await #expect(throws: ErreurService.self) {
            try await service("resident").corrigerSuite(correction, 2, de: 41, dans: residence)
        }
        let admin = service("administrateur")
        await #expect(throws: ErreurService.self) { try await admin.supprimerSuite(3, de: 41, dans: residence) }
        await #expect(throws: ErreurService.self) {
            try await admin.corrigerSuite(correction, 3, de: 41, dans: residence)
        }
        #expect(try conseil.detailSimule(41).suites.count == 3 && admin.detailSimule(41).suites.count == 3)
    }

    @Test func lesGestesDUneEntreeSontRealisesParLesDeuxServices() {
        let reel: any ServiceGestesAffaire = ServiceAPI()
        let simule: any ServiceGestesAffaire = ServiceSimule()
        #expect(reel is ServiceAPI && simule is ServiceSimule)
    }
}
