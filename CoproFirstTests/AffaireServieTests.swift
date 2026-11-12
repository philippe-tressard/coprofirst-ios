// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

// Ce que les contrats 1.20.0 et 1.21.0 servent (#125, #127), au plancher depuis 1.27.0 :
// lu par les types générés, sans rien recomposer.

/// Une affaire de `TicketRead` (une actualité publiée si `actualite`), avec `extra` ajouté
/// tel quel au JSON servi ; les libellés requis que `extra` ne sert pas valent `""`.
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
        """# + nature + requis(extra) + extra + "}"
    let ticket = try Relecture.generee(Components.Schemas.TicketRead.self, json: json)
    let suites = try Relecture.generee([Components.Schemas.TicketEvolutionRead].self, json: evolutions)
    return DetailAffaire.lue(ticket, evolutions: suites)
}

/// Les libellés que `TicketRead` exige (contrat 1.21.0), vides, quand `extra` ne les sert pas.
private func requis(_ extra: String) -> String {
    ["suivi_actualite_libelle", "frequence_libelle"]
        .filter { !extra.contains("\"\($0)\"") }
        .map { ", \"\($0)\": \"\"" }
        .joined()
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
        #expect(ouverte.droits.corriger && !ouverte.contenuFige, "`peut_corriger` non servi (facultatif)")
        let fermee = try affaire("")
        #expect(!fermee.droits.corriger, "ni l'un ni l'autre servi : pas de crayon")
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
    }

    @Test func uneSuiteDitSonNouvelEtatTelQueServi() throws {
        let entree = { (extra: String) in
            #"[{"id": 1, "ticket_id": 41, "type": "etat", "cree_le": "2026-11-09T10:00:00", "#
                + #""ancien_statut": "ouvert", "nouveau_statut": "en_cours", "perimetre_precise_libelle": "", "#
                + #""nouveau_statut_libelle": \#(extra)}]"#
        }
        // L'ancien état, et le nouveau servi vide, se lisent dans les référentiels servis
        // avec l'affaire (`statuts[].libelle`, #105) — plus dans une table.
        let servis = try FixturesReferentielsAffaires.lus()
        let servie = try affaire("", evolutions: entree(#""Chez le syndic (servi)""#))
        #expect(servie.suites.first?.changementDEtat(servis) == "Ouvert → Chez le syndic (servi)")
        let vide = try affaire("", evolutions: entree(String(repeating: "\"", count: 2)))
        #expect(
            vide.suites.first?.changementDEtat(servis) == "Ouvert → Chez le syndic",
            "servi vide avec la Suite : les référentiels servis")
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
        return try #require(generes.map(Prestataire.init).first)
    }

    @Test func lesNumerosSeLisentTelsQueServis() throws {
        #expect(try prestataire(#", "telephones": ["01 99 00 00 13"]"#).telephones == ["01 99 00 00 13"])
        #expect(try prestataire(#", "telephones": []"#).telephones == [], "servis : aucun, même si le champ en porte")
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
        let anterieur = BailDuLocataire(try Relecture.generee(Components.Schemas.BailLocataireOut.self, json: json))
        #expect(anterieur.lotEtageLibelle == nil && anterieur.lotEtage == 2, "non servi (facultatif) : le nombre")
    }
}
