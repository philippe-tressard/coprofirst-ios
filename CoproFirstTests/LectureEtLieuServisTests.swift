// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import CoproFirst

// « Qui la lit » (#129) et le lieu (#130) : chaque route LIT ce que le serveur sert, par le
// client généré et ses types. Rien n'est recomposé ici — ni la pastille, ni le lieu, que
// l'app ne nomme jamais par l'arbre des périmètres.

/// Un serveur qui sert un corps par chemin (sous `/api`, sans requête) ; 404 ailleurs.
private struct TransportParRoute: ClientTransport {
    let corps: [String: String]

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws
        -> (HTTPResponse, HTTPBody?) {
        let chemin = (request.path ?? "").split(separator: "?").first.map(String.init) ?? ""
        let route = chemin.hasPrefix("/api") ? String(chemin.dropFirst(4)) : chemin
        guard let servi = corps[route] else { return (HTTPResponse(status: .notFound), nil) }
        var reponse = HTTPResponse(status: .ok)
        reponse.headerFields[.contentType] = "application/json"
        return (reponse, HTTPBody(servi))
    }
}

private func service(_ corps: [String: String]) -> ServiceAPI {
    ServiceAPI(transport: { _ in TransportParRoute(corps: corps) })
}

private let residence = ServiceSimule.residence
/// La pastille « CS » telle que coprofirst v3.88.1 la sert.
private let lectureCS = Apercu.lecturesServies["cs"] ?? "null"

/// Une affaire de `TicketRead`, avec `extra` tel que servi.
private func ticket(_ id: Int, _ extra: String = "") -> String {
    #"""
    {"id": \#(id), "numero": "TK-\#(id)", "titre": "Essai", "description": "", "categorie": "panne",
     "statut": "ouvert", "priorite": "normale", "cree_le": "2026-11-02T09:00:00", "urgente": false,
     "categorie_libelle": "Panne", "statut_libelle": "Ouvert", "close": false, "colonne_kanban": null,
     "nouveau": false, "nom_proprietaire": "Camille Essai", "perimetre_libelle": "Bât. 2 › Toit",
     "frequence_libelle": "", "suivi_actualite_libelle": ""
    """# + extra + "}"
}

// MARK: - #129 : qui la lit

@Suite struct LectureServieTests {
    @Test func laListeDesAffairesLitLaPastilleServie() async throws {
        let corps = "[" + ticket(9, ", \"lecture\": " + lectureCS) + "," + ticket(10) + "]"
        let affaires = try await service(["/tickets": corps]).affaires(residence)
        let servie = try #require(affaires.first { $0.id == 9 }?.lecture)
        #expect(servie.court == "CS" && servie.icones == ["shield-check"])
        #expect(servie.enClair() == "Qui la lit : Conseil syndical seul. " + servie.phrase)
        #expect(affaires.first { $0.id == 10 }?.lecture == nil, "non servie : aucune pastille")
    }

    @Test func leDetailLitLaPastilleEtLeLieuPreciseDUneSuite() async throws {
        let suites = #"""
            [{"id": 1, "type": "etat", "cree_le": "2026-11-02T10:00:00", "ticket_id": 9,
              "nouveau_statut": "en_cours", "nouveau_statut_libelle": "Chez le syndic",
              "perimetre_precise_libelle": "Périmètre précisé : 🔹 Bât. 2"},
             {"id": 2, "type": "commentaire", "cree_le": "2026-11-02T11:00:00", "ticket_id": 9,
              "nouveau_statut_libelle": "", "perimetre_precise_libelle": ""}]
            """#
        let detail = try await service([
            "/tickets/9": ticket(9, ", \"lecture\": " + lectureCS),
            "/tickets/9/evolutions": suites, "/tickets/9/messages": "[]",
        ]).affaire(9, dans: residence)
        #expect(detail.lecture?.cle == "cs")
        #expect(detail.lieu == "Bât. 2 › Toit")
        #expect(detail.suites.map(\.perimetrePrecise) == ["Périmètre précisé : 🔹 Bât. 2", nil])
        #expect(detail.suites.first?.nouveauStatutLibelle == "Chez le syndic")
        // Ce serveur ne sert pas `/tickets/referentiels` : l'affaire se lit quand même (#105) —
        // rien de ce qu'ils ouvrent n'est offert, et l'état servi avec elle reste en clair.
        #expect(detail.referentiels == .vides && SaisieSuite.etats(pour: detail).isEmpty)
        #expect(detail.etat == EtatServi(code: "ouvert", libelle: "Ouvert"))
    }

    @Test func personneExcluRienNeSeMontre() throws {
        let tous = try #require(Apercu.lecture("tous"))
        #expect(tous.parDefaut)
        #expect(Lecture.aMontrer(tous) == nil, "par défaut : rien sur la carte (`PastilleLecture` du site)")
        #expect(Lecture.aMontrer(nil) == nil)
        #expect(Lecture.aMontrer(Apercu.lecture("reserve"))?.perimetreReserve == true)
    }

    @Test func unSondageSeDitAuMasculin() throws {
        let cs = try #require(Apercu.lecture("cs"))
        #expect(cs.enClair(masculin: true).hasPrefix("Qui le lit : "))
    }

    /// Dans le `meta` libre du fil, une pastille illisible n'emporte pas le lieu (`Tolere`).
    @Test func unePastilleIllisibleDuFilNEmportePasLeLieu() throws {
        let json = #"{"affaire": {"lecture": {"cle": 12}, "perimetre_libelle": "Jardin"}}"#
        let meta = try #require(MetaDuFil(json: json))
        #expect(meta.affaire?.lecture?.valeur == nil)
        #expect(LieuServi.lieu(meta.affaire?.perimetreLibelle) == "Jardin")
    }

    @Test func chaquePictogrammeDesPastillesServiesASonSymbole() {
        let icones = Apercu.lecturesServies.keys.compactMap(Apercu.lecture).flatMap(\.icones) + ["lock"]
        #expect(!icones.isEmpty)
        #expect(icones.filter { Pictogrammes.table[$0] == nil }.isEmpty, "rendus en point : \(icones)")
    }
}

// MARK: - #130 : le lieu

@Suite struct LieuServiTests {
    @Test func servi_ilFaitFoi_videIlSeTait() {
        #expect(LieuServi.lieu("Bât. 2 › Toit") == "Bât. 2 › Toit")
        #expect(LieuServi.lieu("") == nil, "le défaut se tait, comme le site")
        #expect(LieuServi.lieu(nil) == nil)
    }

    /// Le lieu d'un accès est celui que le serveur nomme — jamais ses codes traduits par
    /// l'arbre des périmètres.
    @Test func unAccesDuParcLitSonLieuServi() async throws {
        // Un vigik d'`AccesAdminOut`, son lieu tel que servi.
        func parc(_ lieu: String) async throws -> AccesDuParc? {
            let acces = #"""
                [{"id": 1, "code": "4521", "porteur_id": 21, "porteur_nom": "Alix Exemple", "porteur_rang": 1,
                  "lot_id": null, "lot_libelle": null, "perimetre_cible": ["bat_a"], "statut": "actif",
                  "chez_locataire": false, "cree_le": "2026-02-10T09:00:00", "perimetre_libelle": "\#(lieu)"}]
                """#
            return try await service(["/acces/admin/vigiks": acces, "/acces/admin/telecommandes": "[]"])
                .parc(residence).first
        }
        #expect(try await parc("Bât. A › Hall")?.lieu == "Bât. A › Hall")
        #expect(try await parc("")?.lieu == nil, "servi vide : le défaut, malgré le code « bat_a »")
    }

    @Test func lesIdeesEtLesAnnoncesLisentQuiEtOu() throws {
        let idees = try FixturesCommunaute.ideesLues()
        let hall = try #require(idees.first { $0.id == 5 })
        #expect(hall.lieu == "Bâtiment A")
        #expect(Lecture.aMontrer(hall.lecture)?.perimetreReserve == true)
        let compost = try #require(idees.first { $0.id == 3 })
        #expect(compost.lieu == nil && Lecture.aMontrer(compost.lecture) == nil, "défaut : ni lieu ni pastille")
        let annonces = try FixturesCommunaute.annoncesLues()
        #expect(annonces.first { $0.id == 23 }?.lieu == "Parking")
        #expect(annonces.first { $0.id == 23 }?.lecture?.cle == "coproprietaires")
    }

    @Test func uneAfficheDuHallTaitLeDefautServi() throws {
        let affiches = try FixturesAnnoncesHall.affichesLues()
        #expect(affiches.first { $0.id == 6 }?.lieu == nil, "servi vide : pas de « Toute la copropriété »")
        #expect(affiches.first { $0.id == 7 }?.lieu == "Bât. A")
    }

    @Test func leFilLitQuiEtOuDansMetaAffaire() throws {
        let fuite = try #require(Apercu.fil.first { $0.id == "ticket_ouvert:41" })
        #expect(fuite.lieu == "Parking")
        #expect(fuite.lecture?.perimetreReserve == true)
        #expect(fuite.natures == ["activite"], "les natures se lisent toujours")
        let sansRien = try #require(Apercu.fil.first { $0.id == "ticket_resolu:31" })
        #expect(sansRien.lieu == nil && Lecture.aMontrer(sansRien.lecture) == nil)
        // `meta` est libre : sans `lecture` ni `perimetre_libelle`, ni pastille ni lieu.
        var sansQuiNiOu = fuite
        sansQuiNiOu.poser(MetaDuFil(json: #"{"affaire": {"natures": ["activite"]}}"#))
        #expect(sansQuiNiOu.lecture == nil && sansQuiNiOu.lieu == nil && sansQuiNiOu.natures == ["activite"])
    }
}
