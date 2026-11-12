// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Testing

@testable import CoproFirst

/// Un toucher sur une carte du fil ouvre TOUJOURS quelque chose — selon `typeLink`.
@Test(arguments: ["ticket_ouvert", "ticket_resolu", "ticket_mis_a_jour", "publication"])
func uneAffaireOuUneActualiteSOuvreSurSonDetail(type: String) {
    #expect(CibleDuFil.pour(type: type, meta: .init(ticketId: 41), lien: "/tickets") == .affaire(id: 41))
}

@Test func unSondageOuvertOuClosSOuvreSurLeSondage() {
    for type in ["sondage_ouvert", "sondage_clos"] {
        #expect(CibleDuFil.pour(type: type, meta: .init(sondageId: 3), lien: "/sondages") == .sondage(id: 3))
    }
}

@Test func unDocumentSOuvreSurSonFichierSeulementSIlAUnePage() {
    let meta = CibleDuFil.Meta(documentId: 7, fichierNom: "pv.pdf")
    #expect(CibleDuFil.pour(type: "document", meta: meta, lien: "/residence") == .document(id: 7, nom: "pv.pdf"))
    // Sans lien, le site ne le montre nulle part : un résumé, comme lui.
    #expect(CibleDuFil.pour(type: "document", meta: meta, lien: nil) == .resume(lien: nil))
}

@Test func toutLeResteSOuvreSurUnResumeJamaisSurRien() {
    #expect(CibleDuFil.pour(type: "annonce", meta: .init(), lien: "/a") == .resume(lien: "/a"))
    #expect(CibleDuFil.pour(type: "inconnu", meta: .init(), lien: nil) == .resume(lien: nil))
    // Une affaire sans identifiant servi ne s'ouvre pas sur un détail vide.
    #expect(CibleDuFil.pour(type: "ticket_ouvert", meta: .init(), lien: nil) == .resume(lien: nil))
}

@Test func leFilSimuleCouvreToutesLesCibles() {
    let cibles = Apercu.fil.map(\.cible)
    #expect(cibles.contains { if case .affaire = $0 { true } else { false } })
    #expect(cibles.contains { if case .sondage = $0 { true } else { false } })
    #expect(cibles.contains { if case .document = $0 { true } else { false } })
    #expect(cibles.contains { if case .resume = $0 { true } else { false } })
    #expect(Set(Apercu.fil.map(\.id)).count == Apercu.fil.count, "identifiants type:id uniques")
}

@Test func unNomDeFichierServiNeSortPasDuDossier() {
    #expect(Fichiers.nomSur("../../etc/passwd", defaut: "x") == "-..-etc-passwd")
    #expect(Fichiers.nomSur("pv:ag/2026.pdf", defaut: "x") == "pv-ag-2026.pdf")
    #expect(Fichiers.nomSur(nil, defaut: "document-7") == "document-7")
    #expect(Fichiers.nomSur("  ..  ", defaut: "d") == "d")
}

@Test func uneRouteDeLectureDitSessionExpireeOuIntrouvable() {
    #expect(ErreurService.depuisLecture(401) == .sessionExpiree)
    #expect(ErreurService.depuisLecture(403) == .introuvable)
    #expect(ErreurService.depuisLecture(404) == .introuvable)
}

@Test func leSondageServiSeLitAvecOuSansResultats() throws {
    // Typé par le contrat 1.5.0 (`SondageDetail`) : décodé comme le client, branché par
    // `DetailSondage(_:moi:)` — le chemin du service réel.
    func lire(_ json: String) throws -> DetailSondage {
        DetailSondage(try Relecture.generee(Components.Schemas.SondageDetail.self, json: json), moi: nil)
    }
    let visible = #"""
        {"id": 3, "question": "Q ?", "description": null, "cloture": false, "mon_vote": null,
         "cree_le": "2026-11-01T10:00:00", "resultats_publics": true,
         "resultats_visibles": true, "options": [{"id": 1, "libelle": "A", "ordre": 0, "nb_votes": 2},
         {"id": 2, "libelle": "B", "ordre": 1, "nb_votes": 1}], "commentaires": []}
        """#
    let lu = try lire(visible)
    #expect(lu.totalVotes == 3 && lu.monVote == nil && lu.resultatsVisibles)
    let masque = #"""
        {"id": 3, "question": "Q ?", "cloture": true, "mon_vote": 2, "resultats_visibles": false,
         "cree_le": "2026-11-01T10:00:00", "resultats_publics": false,
         "options": [{"id": 1, "libelle": "A", "ordre": 0}]}
        """#
    let clos = try lire(masque)
    #expect(clos.options.first?.nbVotes == nil, "masqué : absent, jamais 0")
    #expect(clos.monVote == 2)
}

@Test func unChangementDEtatSeDitAvecLesLibellesDuSite() {
    let suite = SuiteAffaire(
        id: 1, type: "etat", date: .now, auteur: nil, contenu: nil, ancienStatut: "ouvert",
        nouveauStatut: "en_cours")
    #expect(suite.changementDEtat == "Ouvert → Chez le syndic")
}
