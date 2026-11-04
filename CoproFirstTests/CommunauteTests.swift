// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// Les deux réalisations du service se conforment : l'accès `parcours.serviceCommunaute`
/// (un transtypage) ne peut pas échouer. Vérifié à la compilation.
@Test func lesDeuxServicesServentLaCommunaute() {
    let reels: [any ServiceCommunaute] = [ServiceAPI(), ServiceSimule(delai: .zero)]
    #expect(reels.count == 2)
}

/// Une Communauté factice : le compte et l'Avis se règlent, le reste ne sert pas.
private struct Factice: ServiceCommunaute {
    var statut = "copropriétaire_résident"
    var motif: String?

    func moiCommunaute(_ installation: Installation) async throws -> MoiCommunaute {
        MoiCommunaute(id: 1, statut: statut, roles: ["résident"], motifRefus: motif)
    }
    func avisCommunaute(_ installation: Installation) async throws -> ListeAvis {
        ListeAvis(avis: [], gestionnaire: false, monAvisId: nil)
    }
    func sondagesCommunaute(_ installation: Installation) async throws -> [SondageResume] { [] }
    func idees(_ installation: Installation) async throws -> [Idee] { [] }
    func proposerIdee(titre: String, description: String, dans installation: Installation) async throws {}
    func voterIdee(_ id: Int, dans installation: Installation) async throws -> String? {
        throw ErreurService.inattendue(500)
    }
    func annonces(_ installation: Installation) async throws -> [Annonce] { [] }
    func deposerAnnonce(_ saisie: SaisieAnnonce, dans installation: Installation) async throws {}
    func changerStatutAnnonce(_ id: Int, statut: String, dans installation: Installation) async throws {}
    func supprimerAnnonce(_ id: Int, dans installation: Installation) async throws {}
    func repondreCommunaute(_ texte: String, a cible: CibleCommunaute, dans installation: Installation) async throws {}
    func supprimerReponseCommunaute(_ id: Int, de cible: CibleCommunaute, dans installation: Installation)
        async throws {}
    func signalerAuConseil(_ cible: CibleCommunaute, motif: String, dans installation: Installation) async throws {}
    func deposerAvis(_ saisie: SaisieAvis, dans installation: Installation) async throws {}
    func corrigerAvis(_ id: Int, _ saisie: SaisieAvis, dans installation: Installation) async throws {}
    func archiverAvis(_ id: Int, archive: Bool, dans installation: Installation) async throws {}
}

@MainActor
@Test func lesOngletsOuvertsSuiventLaRegleDuSiteEtLaConclusionDuServeur() async {
    let residence = ServiceSimule.residence

    let resident = EtatCommunaute()
    await resident.ouvrir(residence, avec: Factice())
    #expect(resident.onglets == OngletCommunaute.allCases, "un résident : les quatre rubriques, dans l'ordre du site")
    #expect(OngletCommunaute.allCases.map(\.libelle) == ["Sondages", "Boîte à idées", "Petites annonces", "Avis"])

    let syndic = EtatCommunaute()
    let profil = "La rubrique Communauté n'est pas accessible à votre profil"
    await syndic.ouvrir(residence, avec: Factice(statut: "syndic", motif: profil))
    #expect(syndic.onglets == [.avis], "réserve « nonGestionnaire » : l'Avis seul")
    #expect(syndic.onglet == .avis)

    let suspendu = EtatCommunaute()
    let motif = "Votre accès à la rubrique Communauté a été définitivement suspendu."
    await suspendu.ouvrir(residence, avec: Factice(motif: motif))
    #expect(suspendu.acces == .ferme(motif), "un motif que la réserve n'explique pas : tout est fermé, mot pour mot")
    #expect(suspendu.onglets.isEmpty)
}

@MainActor
@Test func unVoteRefuseRevientEnArriereEtLeDit() async {
    let etat = EtatCommunaute()
    let idee = Idee(
        id: 1, titre: "Composteur", description: "", auteurId: 2, statut: "ouverte", creeLe: .now, nbVotes: 3,
        monVote: false, archivee: false, reponses: [])
    etat.idees = ListeChargee(phase: .pret, elements: [idee])
    await etat.basculerVote(idee, ServiceSimule.residence, avec: Factice())
    #expect(etat.idees.elements.first?.nbVotes == 3, "le serveur a refusé : le compte revient")
    #expect(etat.idees.elements.first?.monVote == false)
    #expect(etat.bandeau?.reussi == false, "et une phrase le dit")
}

@Test func laSaisieDevientDuHTMLSansBaliseVenueDeLUtilisateur() {
    #expect(HTMLDeSaisie.depuis("Bonjour\nà tous\n\nSecond <b>bloc</b> & fin") ==
        "<p>Bonjour<br>à tous</p><p>Second &lt;b&gt;bloc&lt;/b&gt; &amp; fin</p>")
    #expect(HTMLDeSaisie.depuis("   \n  ").isEmpty)
}

@Test func unAvisDemandeCeQueLeServeurExigeSelonLaNote() {
    var saisie = SaisieAvis(note: 2, titre: "Titre", description: "Texte")
    #expect(!saisie.complete, "sous le seuil, ce qui a manqué est obligatoire")
    saisie.remarque = "Les comptes"
    #expect(saisie.complete)
    #expect(saisie.consentementEnvoye == nil, "pas d'accord de diffusion sous le seuil")

    saisie.note = 5
    #expect(saisie.remarqueEnvoyee == nil, "la remarque ne part plus au-dessus du seuil")
    #expect(!saisie.complete, "à partir du seuil, Oui ou Non — aucune réponse par défaut")
    saisie.consentement = false
    #expect(saisie.complete)

    saisie.note = 0
    #expect(!saisie.complete, "une note est obligatoire")
}

@Test func uneReponseNonTypeeSeRelitAvecSesDatesSansFuseau() throws {
    struct Brut: Encodable {
        let id = 3, titre = "Idée", description = "<p>x</p>", statut = "ouverte"
        let cree_le = "2026-11-04T08:30:00", nb_votes = 2, mon_vote = true  // swiftlint:disable:this identifier_name
    }
    let idee = try Relecture.lire(Idee.self, depuis: Brut())
    #expect(idee.nbVotes == 2 && idee.monVote)
    #expect(idee.creeLe == ISO8601DateFormatter().date(from: "2026-11-04T08:30:00Z"), "sans fuseau = UTC")
}
