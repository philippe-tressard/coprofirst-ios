// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

// Ce que le serveur sert d'une affaire, lu par ses types générés sans rien recomposer
// (#125, #127) : le crayon, l'état en clair, le rythme, les numéros, l'étage. Un champ
// facultatif que le serveur ne sert pas vaut « non » ou « rien » (défaut fermé) — jamais
// une valeur déduite d'un autre champ.

/// Une affaire de `TicketRead` (une actualité publiée si `actualite`), avec `extra` ajouté
/// tel quel au JSON servi ; `rythme` et `suivi` : les deux libellés que le contrat exige.
private func affaire(
    _ extra: String, actualite: Bool = false, rythme: String = "", suivi: String = "", evolutions: String = "[]"
) throws -> DetailAffaire {
    let nature =
        actualite
        ? #""categorie": "actualite", "statut": "publie", "statut_libelle": "Publiée""#
        : #""categorie": "sinistre", "statut": "en_cours", "statut_libelle": "Chez le syndic""#
    let json =
        #"""
        {"id": 41, "numero": "A-0041", "titre": "T", "description": "", "categorie_libelle": "Sinistre",
         "priorite": "normale", "urgente": false, "close": false, "colonne_kanban": "syndic",
         "nouveau": false, "nom_proprietaire": "", "cree_le": "2026-11-09T09:00:00", "peut_repondre": true,
         "frequence_libelle": "\#(rythme)", "suivi_actualite_libelle": "\#(suivi)",
        """# + nature + extra + "}"
    let ticket = try Relecture.generee(Components.Schemas.TicketRead.self, json: json)
    let suites = try Relecture.generee([Components.Schemas.TicketEvolutionRead].self, json: evolutions)
    return DetailAffaire.lue(ticket, evolutions: suites)
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

    /// Le crayon ne se déduit plus du droit sur le contenu : non servi, il n'est pas offert.
    @Test func sansPeutCorrigerAucunCrayon() throws {
        let sansCrayon = try affaire(#", "peut_modifier": true"#)
        #expect(!sansCrayon.droits.corriger, "`peut_modifier` seul n'ouvre pas la correction")
        #expect(!GesteAffaire.offerts(pour: sansCrayon, conseil: false).contains(.modifier))
        #expect(!(try affaire("")).droits.corriger)
    }

    // MARK: - #127 : l'état en clair, servi

    @Test func lEtatDUneAffaireSeLitTelQueServi() throws {
        let lue = try affaire("")
        #expect(lue.etat == EtatServi(code: "en_cours", libelle: "Chez le syndic"))
    }

    @Test func uneActualiteMontreSonSuiviServi() throws {
        let suivie = try affaire(#", "suivi_actualite": "résolu""#, actualite: true, suivi: "Résolu")
        #expect(suivie.etat == EtatServi(code: "résolu", libelle: "Résolu"))
        #expect(try affaire("", actualite: true).etat == nil, "une actualité sans suivi n'en montre aucun")
    }

    @Test func uneSuiteDitSonNouvelEtatTelQueServi() throws {
        let entree = { (libelle: String) in
            #"[{"id": 1, "ticket_id": 41, "type": "etat", "cree_le": "2026-11-09T10:00:00", "#
                + #""ancien_statut": "ouvert", "nouveau_statut": "en_cours", "perimetre_precise_libelle": "", "#
                + #""nouveau_statut_libelle": "\#(libelle)"}]"#
        }
        // L'ancien état, et un nouvel état que la Suite sert vide, se lisent dans les
        // référentiels servis avec l'affaire (`statuts[].libelle`, #105) — plus dans une table.
        let servis = try FixturesReferentielsAffaires.lus()
        let servie = try affaire("", evolutions: entree("Chez le syndic (servi)"))
        #expect(servie.suites.first?.changementDEtat(servis) == "Ouvert → Chez le syndic (servi)")
        let vide = try affaire("", evolutions: entree(""))
        #expect(
            vide.suites.first?.changementDEtat(servis) == "Ouvert → Chez le syndic",
            "servi vide avec la Suite : les référentiels servis")
    }

    // MARK: - #125 : le rythme, servi — celui du contrat d'abord

    @Test func lIntervenantPorteLeRythmeDuContratDAbord() throws {
        let prestataire = #", "prestataire_nom": "Ascenseurs (fictif)""#
        #expect(try affaire(prestataire, rythme: "↺ 1×/an").intervenant == "Ascenseurs (fictif) · ↺ 1×/an")
        let sousContrat = try affaire(
            prestataire + #", "contrat": {"id": 1, "frequence_libelle": "↺ Mensuel"}"#, rythme: "↺ 1×/an")
        #expect(sousContrat.intervenant == "Ascenseurs (fictif) · ↺ Mensuel")
        #expect(try affaire(prestataire).intervenant == "Ascenseurs (fictif)")
        #expect(try affaire("", rythme: "↺ Mensuel").intervenant == nil, "sans prestataire : rien")
    }

    // MARK: - #125 : un lien d'appel par numéro servi

    private func prestataire(_ numeros: String) throws -> Prestataire {
        let json =
            #"[{"id": 1, "nom": "Ascenseurs (fictif)", "specialite": "ascenseur", "actif": true, "#
            + #""telephone": "01 99 00 00 11, 01 99 00 00 12, 01 99 00 00 11", "telephones": "# + numeros + "}]"
        let generes = try Relecture.generee([Components.Schemas.PrestataireRead].self, json: json)
        return try #require(generes.map(Prestataire.init).first)
    }

    @Test func lesNumerosSeLisentTelsQueServis() throws {
        #expect(try prestataire(#"["01 99 00 00 13"]"#).telephones == ["01 99 00 00 13"])
        #expect(try prestataire("[]").telephones == [], "servis : aucun, même si le champ en porte")
    }

    @Test func lesFichesSimuleesPortentLeursNumerosServis() throws {
        let controles = try #require(try FixturesPrestataires.lus().first { $0.id == 2 })
        #expect(controles.telephones == ["01 99 00 00 21"], "le serveur a retiré le doublon saisi")
    }

    // MARK: - #127 : l'étage en clair d'un bail

    @Test func lEtageDuBailSeLitTelQueServi() throws {
        #expect(try FixturesAcces.monBailLu().lotEtageLibelle == "2ème")
    }
}
