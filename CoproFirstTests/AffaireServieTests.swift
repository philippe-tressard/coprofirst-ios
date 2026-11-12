// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

// Ce que les contrats 1.20.0 et 1.21.0 servent au-dessus du plancher (#125, #127), relu
// sans rien recomposer : chaque champ servi, puis absent (installation antérieure : le
// comportement d'avant), puis illisible (défaut fermé).

/// Une affaire de `TicketRead` (une actualité publiée si `actualite`), avec `extra` ajouté
/// tel quel au JSON servi.
private func affaire(_ extra: String, actualite: Bool = false, evolutions: String = "[]") throws -> DetailAffaire {
    let nature =
        actualite
        ? #""categorie": "actualite", "statut": "publie", "statut_libelle": "Publiée""#
        : #""categorie": "sinistre", "statut": "en_cours", "statut_libelle": "Chez le syndic""#
    let json =
        #"""
        {"id": 41, "numero": "A-0041", "titre": "T", "description": "", "categorie_libelle": "Sinistre",
         "priorite": "normale", "urgente": false, "close": false, "colonne_kanban": "syndic",
         "nouveau": false, "nom_proprietaire": "", "cree_le": "2026-11-09T09:00:00", "peut_repondre": true,
        """# + nature + extra + "}"
    let ticket = try Relecture.generee(Components.Schemas.TicketRead.self, json: json)
    let suites = try Relecture.generee([Components.Schemas.TicketEvolutionRead].self, json: evolutions)
    return DetailAffaire.lue(ticket, corps: Data(json.utf8), evolutions: suites, corpsEvolutions: Data(evolutions.utf8))
}

struct AffaireServieTests {
    // MARK: - #127 : le crayon suit `peut_corriger`, comme le site

    /// L'auteur d'une affaire engagée garde le crayon et les options ; il ne corrige plus le contenu.
    @Test func leCrayonSuitPeutCorriger() throws {
        let auteur = try affaire(#", "peut_modifier": false, "peut_corriger": true"#)
        #expect(GesteAffaire.offerts(pour: auteur, conseil: false) == [.lien, .repondre, .modifier, .options])
        #expect(auteur.contenuFige)
        let lecteur = try affaire(#", "peut_modifier": false, "peut_corriger": false"#)
        #expect(!GesteAffaire.offerts(pour: lecteur, conseil: false).contains(.modifier))
    }

    @Test func sansPeutCorrigerLeCrayonSuitPeutModifierCommeAvant() throws {
        let ouverte = try affaire(#", "peut_modifier": true"#)
        #expect(ouverte.droits.corriger && !ouverte.contenuFige, "installation antérieure au contrat 1.21.0")
        let fermee = try affaire("")
        #expect(!fermee.droits.corriger, "ni l'un ni l'autre servi : pas de crayon")
    }

    @Test func unCorpsIllisibleGardeLeCrayonDAvant() throws {
        let json =
            #"{"id": 41, "numero": "A", "titre": "T", "description": "", "categorie": "x", "#
            + #""categorie_libelle": "X", "statut": "ouvert", "statut_libelle": "Ouvert", "priorite": "normale", "#
            + #""urgente": false, "close": false, "colonne_kanban": null, "nouveau": false, "#
            + #""nom_proprietaire": "", "cree_le": "2026-11-09T09:00:00", "peut_modifier": true}"#
        let ticket = try Relecture.generee(Components.Schemas.TicketRead.self, json: json)
        let lue = DetailAffaire.lue(ticket, corps: Data("<html>".utf8), evolutions: [], corpsEvolutions: nil)
        #expect(lue.droits.corriger && !lue.contenuFige, "illisible : le crayon d'avant (`peut_modifier`)")
        #expect(lue.suiviActualiteLibelle == nil && lue.intervenant == nil)
    }

    // MARK: - #127 : l'état en clair, servi

    @Test func lEtatDUneAffaireSeLitTelQueServi() throws {
        let lue = try affaire("")
        #expect(lue.etat == EtatServi(code: "en_cours", libelle: "Chez le syndic"))
    }

    @Test func uneActualiteMontreSonSuiviServi() throws {
        let suivie = try affaire(
            #", "suivi_actualite": "résolu", "suivi_actualite_libelle": "Résolu""#, actualite: true)
        #expect(suivie.etat == EtatServi(code: "résolu", libelle: "Résolu"))
        let vide = String(repeating: "\"", count: 2)
        let sansSuivi = try affaire(#", "suivi_actualite_libelle": "# + vide, actualite: true)
        #expect(sansSuivi.etat == nil, "une actualité sans suivi n'en montre aucun")
        let anterieure = try affaire("", actualite: true)
        #expect(anterieure.etat == EtatServi(code: "publie", libelle: "Publiée"), "non servi : le statut, comme avant")
    }

    @Test func uneSuiteDitSonNouvelEtatTelQueServi() throws {
        let entree = { (extra: String) in
            #"[{"id": 1, "ticket_id": 41, "type": "etat", "cree_le": "2026-11-09T10:00:00", "#
                + #""ancien_statut": "ouvert", "nouveau_statut": "en_cours"\#(extra)}]"#
        }
        // L'ancien état, et le nouveau d'une installation antérieure, se lisent dans les
        // référentiels servis avec l'affaire (`statuts[].libelle`, #105) — plus dans une table.
        let servis = try FixturesReferentielsAffaires.lus()
        let servie = try affaire("", evolutions: entree(#", "nouveau_statut_libelle": "Chez le syndic (servi)""#))
        #expect(servie.suites.first?.changementDEtat(servis) == "Ouvert → Chez le syndic (servi)")
        let anterieure = try affaire("", evolutions: entree(""))
        #expect(
            anterieure.suites.first?.changementDEtat(servis) == "Ouvert → Chez le syndic",
            "non servi avec la Suite : les référentiels servis")
    }

    // MARK: - #125 : le rythme, servi — celui du contrat d'abord

    @Test func lIntervenantPorteLeRythmeDuContratDAbord() throws {
        let prestataire = #", "prestataire_nom": "Ascenseurs (fictif)", "frequence_libelle": "↺ 1×/an""#
        #expect(try affaire(prestataire).intervenant == "Ascenseurs (fictif) · ↺ 1×/an")
        let sousContrat = try affaire(prestataire + #", "contrat": {"id": 1, "frequence_libelle": "↺ Mensuel"}"#)
        #expect(sousContrat.intervenant == "Ascenseurs (fictif) · ↺ Mensuel")
        #expect(try affaire(#", "prestataire_nom": "Ascenseurs (fictif)""#).intervenant == "Ascenseurs (fictif)")
        #expect(try affaire(#", "frequence_libelle": "↺ Mensuel""#).intervenant == nil, "sans prestataire : rien")
    }

    // MARK: - #125 : un lien d'appel par numéro servi

    private func prestataire(_ extra: String) throws -> Prestataire {
        let json =
            #"[{"id": 1, "nom": "Ascenseurs (fictif)", "specialite": "ascenseur", "actif": true, "#
            + #""telephone": "01 99 00 00 11, 01 99 00 00 12, 01 99 00 00 11""# + extra + "}]"
        let generes = try Relecture.generee([Components.Schemas.PrestataireRead].self, json: json)
        return try #require(Prestataire.lus(generes, corps: Data(json.utf8)).first)
    }

    @Test func lesNumerosSeLisentTelsQueServis() throws {
        #expect(try prestataire(#", "telephones": ["01 99 00 00 13"]"#).telephones == ["01 99 00 00 13"])
        #expect(try prestataire(#", "telephones": []"#).telephones == [], "servis : aucun, même si le champ en porte")
        #expect(
            try prestataire("").telephones == ["01 99 00 00 11", "01 99 00 00 12"],
            "non servis : le champ découpé, sans doublon, comme avant")
    }

    @Test func lesFichesSimuleesPortentLeursNumerosServis() throws {
        let controles = try #require(try FixturesPrestataires.lus().first { $0.id == 2 })
        #expect(controles.telephones == ["01 99 00 00 21"], "le serveur a retiré le doublon saisi")
    }

    // MARK: - #127 : l'étage en clair d'un bail et d'un rapprochement

    @Test func lEtageDuBailSeLitTelQueServi() throws {
        let bail = try FixturesAcces.monBailLu()
        #expect(bail.lotEtageLibelle == "2ème")
        let json = FixturesAcces.monBail.replacingOccurrences(of: #", "lot_etage_libelle": "2ème""#, with: "")
        let anterieur = BailDuLocataire.lu(
            try Relecture.generee(Components.Schemas.BailLocataireOut.self, json: json), corps: Data(json.utf8))
        #expect(anterieur.lotEtageLibelle == nil && anterieur.lotEtage == 2, "non servi : le nombre, comme avant")
    }
}
