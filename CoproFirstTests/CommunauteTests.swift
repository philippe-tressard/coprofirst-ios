// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
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
    func peutCreerUnSondage(_ installation: Installation) async throws -> Bool { false }
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
    func signalerAuConseil(_ cible: CibleSignalement, motif: String, dans installation: Installation) async throws {}
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

/// L'API simulée retient un vote : la liste relue après le geste le montre (sans quoi
/// le cœur se viderait aussitôt — vu au test d'interface).
@Test func unVoteSimuleSeRelitEtSeRetire() async throws {
    let service = ServiceSimule(delai: .zero)
    let residence = ServiceSimule.residence
    let avant = try #require(try await service.idees(residence).first { $0.id == 5 })
    #expect(try await service.voterIdee(5, dans: residence) == "Vote enregistré")
    let apres = try #require(try await service.idees(residence).first { $0.id == 5 })
    #expect(apres.monVote != avant.monVote && apres.nbVotes == avant.nbVotes + 1)
    #expect(try await service.voterIdee(5, dans: residence) == "Vote retiré")
    #expect(try await service.idees(residence).first { $0.id == 5 } == avant, "le second toucher retire le vote")
}

/// « Supprimer l'annonce » se LIT dans `AnnonceRead.peut_supprimer` (l'auteur ou le conseil,
/// #83) : l'app ne le déduit plus de ses rôles. Absent, le geste n'est pas offert.
@Test func supprimerUneAnnonceSeLitDansLAnnonceServie() async throws {
    let json = #"""
        [{"id": 1, "titre": "Vélo", "description": "", "type_annonce": "vente", "categorie": "divers",
          "negotiable": false, "photos": [], "statut": "en_cours", "auteur_id": 3, "est_auteur": false,
          "peut_supprimer": true, "archivee": false, "cree_le": "2026-11-02T09:00:00", "nb_reponses": 0,
          "perimetre_libelle": ""},
         {"id": 2, "titre": "Lampe", "description": "", "type_annonce": "don", "categorie": "divers",
          "negotiable": false, "photos": [], "statut": "en_cours", "auteur_id": 3, "est_auteur": false,
          "archivee": false, "cree_le": "2026-11-02T09:00:00", "nb_reponses": 0, "perimetre_libelle": ""}]
        """#
    let lues = try await client(servant: json).getAnnonces().ok.body.json.map(Annonce.init)
    #expect(lues.map(\.peutSupprimer) == [true, false])
}

// MARK: - #87 : créer un sondage, rédiger la FAQ — des droits SERVIS

/// `GET /sondages/gestes` et `GET /faq/gestes` se lisent par les routes générées : aucun
/// rôle n'en décide. Le compte simulé est du conseil — puis ne modère plus.
@MainActor
@Test func creerUnSondageEtRedigerLaFAQSontServis() async throws {
    let service = ServiceSimule(delai: .zero)
    let residence = ServiceSimule.residence
    let etat = EtatCommunaute()
    await etat.charger(.sondages, residence, avec: service)
    #expect(etat.peutCreerUnSondage)
    #expect(try await service.peutRedigerLaFAQ(residence))
    service.profilSimule.estModerateur = false
    await etat.charger(.sondages, residence, avec: service)
    #expect(!etat.peutCreerUnSondage, "le serveur dit non : le rôle « conseil_syndical » n'y change rien")
    #expect(try await !service.peutRedigerLaFAQ(residence))
}

/// La route générée lit la réponse telle que le serveur la sert.
@Test func lesGestesServisSeLisentParLesRoutesGenerees() async throws {
    let faq = try await client(servant: #"{"peut_rediger": true}"#).getFaqGestes().ok.body.json
    #expect(faq.peutRediger)
    let sondages = try await client(servant: #"{"peut_creer": false}"#).getSondagesGestes().ok.body.json
    #expect(!sondages.peutCreer)
}
