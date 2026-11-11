// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// « Modifier l'affaire » (✏️, #91) : n'envoyer que ce qui a changé, et ne rien
/// réenregistrer qui perdrait ce que l'app ne sait pas écrire.
@MainActor
struct ModifierAffaireTests {
    /// Une affaire dont le lecteur corrige le contenu (`peut_modifier`) — sauf `contenu: false`.
    private func affaire(
        description: String = "<p>Une fuite.</p>", perimetres: [String] = ["parking"], contenu: Bool = true
    ) -> DetailAffaire {
        DetailAffaire(
            id: 41, numero: "A-0041", titre: "Fuite", description: description, categorie: "sinistre",
            statut: "en_cours", urgente: false, creeLe: .now, auteur: nil, lieu: nil, photos: [], suites: [],
            droits: DroitsServisAffaire(modifier: contenu, corriger: true), perimetres: perimetres)
    }

    /// Le crayon sans le contenu (#127) : l'auteur d'une affaire engagée n'en règle plus
    /// que l'urgence — un titre, un lieu changés ne partent pas.
    @Test func unContenuFigeNEnvoieQueLUrgence() {
        let origine = affaire(contenu: false)
        var saisie = SaisieAffaire(modifiant: origine)
        saisie.titre = "Fuite au parking"
        saisie.perimetre = "jardin"
        #expect(origine.contenuFige && saisie.edition(depuis: origine).vide && !saisie.prete(depuis: origine))
        saisie.urgente = true
        #expect(saisie.edition(depuis: origine) == EditionAffaire(urgente: true) && saisie.prete(depuis: origine))
        #expect(!affaire().contenuFige)
    }

    /// Le faux serveur refuse ce que le vrai refuse : un contenu sans `peut_modifier`.
    @Test func leServeurSimuleRefuseUnContenuFige() async throws {
        let service = ServiceSimule(delai: .zero)
        service.profilSimule.roles.removeAll { $0 == "conseil_syndical" }
        let residence = ServiceSimule.residence
        let avant = try service.detailSimule(41)
        #expect(avant.droits.corriger && avant.contenuFige, "l'auteur de 41, engagée, garde le crayon seul")
        await #expect(throws: ErreurService.self) {
            try await service.enregistrer(EditionAffaire(titre: "Autre"), de: 41, dans: residence)
        }
        try await service.enregistrer(EditionAffaire(urgente: false), de: 41, dans: residence)
        #expect(try !service.detailSimule(41).urgente && service.detailSimule(41).titre == avant.titre)
    }

    @Test func uneSaisieIntacteNEnvoieRien() {
        let origine = affaire()
        let saisie = SaisieAffaire(modifiant: origine)
        #expect(saisie.description == "Une fuite." && saisie.perimetre == "parking")
        #expect(saisie.edition(depuis: origine).vide && !saisie.prete(depuis: origine))
    }

    @Test func seulsLesChampsChangesPartent() {
        let origine = affaire()
        var saisie = SaisieAffaire(modifiant: origine)
        saisie.titre = "  Fuite au parking  "
        saisie.perimetre = nil
        let edition = saisie.edition(depuis: origine)
        #expect(edition == EditionAffaire(titre: "Fuite au parking", perimetres: []), "plus de lieu : une liste vide")
        #expect(saisie.prete(depuis: origine))
        saisie.description = "Une fuite.\n\nLe seau est posé."
        #expect(saisie.edition(depuis: origine).descriptionHTML == "<p>Une fuite.</p><p>Le seau est posé.</p>")
    }

    @Test func unBogueNeGardeNiLieuNiUrgence() {
        let origine = affaire()
        var saisie = SaisieAffaire(modifiant: origine)
        saisie.categorie = SaisieAffaire.bogue
        #expect(saisie.edition(depuis: origine) == EditionAffaire(categorie: "bug", perimetres: []))
    }

    @Test func uneMiseEnFormeDuSiteNeSeReecritPas() {
        #expect(TexteDuSite.saisi(html: "<p>a &lt; b<br>c</p><p>d</p>") == "a < b\nc\n\nd")
        #expect(TexteDuSite.saisi(html: "<p>a<br/>b</p>") == "a\nb")
        #expect(TexteDuSite.saisi(html: "Un texte d'avant l'éditeur.") == "Un texte d'avant l'éditeur.")
        let riches = ["<p>Le sol est <strong>glissant</strong>.</p>", "<ul><li><p>a</p></li></ul>", "<p>a&nbsp;: b</p>"]
        for riche in riches {
            #expect(TexteDuSite.saisi(html: riche) == nil, "\(riche) perdrait sa mise en forme")
        }
        let figee = affaire(description: "<p>Le sol est <strong>glissant</strong>.</p>")
        var saisie = SaisieAffaire(modifiant: figee)
        saisie.titre = "Fuite au parking"
        #expect(saisie.prete(depuis: figee) && saisie.edition(depuis: figee).descriptionHTML == nil)
    }

    @Test func plusieursLieuxNeSeRamenentPasAUn() {
        let origine = affaire(perimetres: ["bat_a", "parking"])
        var saisie = SaisieAffaire(modifiant: origine)
        saisie.perimetre = "jardin"
        #expect(!origine.lieuModifiable && saisie.edition(depuis: origine).perimetres == nil)
    }

    @Test(arguments: [41, 12, 38, 31, 44, 45])
    func uneAffaireSimuleePorteUneCategorieDuSite(id: Int) throws {
        let detail = try #require(try ServiceSimule.affaires(id, conseil: true))
        let servies = try FixturesReferentielsAffaires.lus()
        #expect(servies.categorie(detail.categorie) != nil, "« \(detail.categorie) » : inconnue de la résidence")
    }

    @Test func laModificationSimuleeChangeLAffaire() async throws {
        let service = ServiceSimule(delai: .zero)
        var saisie = SaisieAffaire(modifiant: try service.detailSimule(38))
        saisie.titre = "Ravalement de la façade sur rue"
        saisie.perimetre = "jardin"
        try await service.enregistrer(
            saisie.edition(depuis: try service.detailSimule(38)), de: 38, dans: ServiceSimule.residence)
        let apres = try service.detailSimule(38)
        #expect(apres.titre == "Ravalement de la façade sur rue")
        #expect(apres.perimetres == ["jardin"] && apres.lieu == "Jardin")
    }
}
