// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import CoproFirst

/// La liaison de la montre (#226) : ce que l'iPhone transmet, ce que la montre en garde, et
/// la lecture de la cloche par le jeton de montre (coprofirst#2771).
@MainActor
struct LiaisonMontreTests {
    private let adresse = URL(string: "https://tilleuls.exemple")!
    private let echeance = Date(timeIntervalSince1970: 2_000_000_000)

    private func liaison(_ adresse: URL? = nil, jeton: String = "jeton-secret-123") -> MessageLiaison {
        .liaison(adresse: adresse ?? self.adresse, residence: "Les Tilleuls", jeton: jeton, expireLe: echeance)
    }

    // MARK: - Le message

    @Test func leMessageFaitLAllerRetourParLeTransport() {
        #expect(MessageLiaison(liaison().donnees) == liaison())
        #expect(MessageLiaison(MessageLiaison.effacement(adresse: adresse).donnees) == .effacement(adresse: adresse))
    }

    @Test func unMessageIncompletOuNonHttpsNeSeLitPas() {
        var donnees = liaison().donnees
        donnees["jeton"] = ""
        #expect(MessageLiaison(donnees) == nil, "jamais une liaison à moitié")
        #expect(MessageLiaison(liaison(URL(string: "http://tilleuls.exemple")!).donnees) == nil, "https seul")
        #expect(MessageLiaison(["geste": "autre", "adresse": adresse.absoluteString]) == nil)
        #expect(MessageLiaison([:]) == nil)
    }

    @Test func leJetonNeParaitDansAucuneTrace() {
        let message = liaison()
        let gardee = LiaisonGardee(adresse: adresse, residence: "R", jeton: "jeton-secret-123", expireLe: echeance)
        var vidages = ["", ""]
        dump(message, to: &vidages[0])
        dump(gardee, to: &vidages[1])
        let porteur = JetonPorteur(jeton: "jeton-secret-123")
        for texte in ["\(message)", String(reflecting: message), "\(gardee)", String(reflecting: gardee), "\(porteur)"]
            + vidages
        {
            #expect(!texte.contains("jeton-secret"), "le jeton paraît dans « \(texte.prefix(60))… »")
        }
    }

    // MARK: - Ce que la montre garde

    @Test func laMontreGardeLaLiaisonEtNEffaceQueLaSienne() {
        let coffre = LiaisonEnMemoire()
        Liaisons.recevoir(liaison(), coffre)
        #expect(coffre.lire()?.residence == "Les Tilleuls")
        Liaisons.recevoir(.effacement(adresse: URL(string: "https://glycines.exemple")!), coffre)
        #expect(coffre.lire() != nil, "l'effacement d'une autre résidence n'efface pas celle-ci")
        Liaisons.recevoir(.effacement(adresse: adresse), coffre)
        #expect(coffre.lire() == nil)
    }

    @Test func laLiaisonEteinteNeRelieNiNEcouteRien() {
        #expect(!LiaisonMontre.active, "allumée seulement sur le geste de Philippe, avec Wear OS (#207)")
        let coffre = LiaisonEnMemoire()
        let montre = LiaisonDeLaMontre(coffre: coffre)
        montre.recevoir(liaison())
        #expect(coffre.lire() == nil, "rien ne se garde")
        #expect(montre.etat == .nonReliee)
    }

    @Test func uneLiaisonEchueNeRelieRien() {
        let coffre = LiaisonEnMemoire()
        Liaisons.recevoir(liaison(), coffre)
        #expect(Liaisons.valide(coffre, maintenant: echeance.addingTimeInterval(-1)) != nil)
        #expect(Liaisons.valide(coffre, maintenant: echeance) == nil)
        #expect(EtatMontre.depuis(coffre, active: true, maintenant: echeance.addingTimeInterval(-1)) != .nonReliee)
        #expect(EtatMontre.depuis(coffre, active: false) == .nonReliee, "liaison éteinte")
    }

    @Test func laMontreSeRelieAuMessageEtSeDelieAuRefus() {
        let coffre = LiaisonEnMemoire()
        let montre = LiaisonDeLaMontre(coffre: coffre, active: true)
        #expect(montre.etat == .nonReliee)
        let futur = MessageLiaison.liaison(
            adresse: adresse, residence: "Les Tilleuls", jeton: "j", expireLe: .now.addingTimeInterval(86_400))
        montre.recevoir(futur)
        guard case .reliee(let residence, .jeton(let gardee)) = montre.etat else {
            Issue.record("la montre n'est pas reliée : \(montre.etat)")
            return
        }
        #expect(residence == "Les Tilleuls")
        #expect(gardee.adresse == adresse)
        montre.jetonRefuse()
        #expect(montre.etat == .nonReliee)
        #expect(coffre.lire() == nil, "le jeton refusé ne se garde pas")
    }

    // MARK: - La lecture par le jeton

    @Test func laClocheSeLitAvecLeJetonEnPorteur() async throws {
        let transport = TransportCloche(statut: .ok)
        let gardee = LiaisonGardee(adresse: adresse, residence: "R", jeton: "jeton-de-montre", expireLe: echeance)
        let alertes = try await ClocheParJeton.alertes(gardee, transport: transport)
        #expect(alertes.map(\.id) == [7])
        #expect(transport.autorisation == "Bearer jeton-de-montre")
        #expect(transport.chemin == "/notifications", "la seule route que le jeton ouvre")
        #expect(transport.hote == "tilleuls.exemple", "vers l'adresse de la liaison, et elle seule")
    }

    @Test func unRefusDuServeurDitLeJetonRefuse() async {
        let gardee = LiaisonGardee(adresse: adresse, residence: "R", jeton: "j", expireLe: echeance)
        await #expect(throws: JetonRefuse.self) {
            _ = try await ClocheParJeton.alertes(gardee, transport: TransportCloche(statut: .unauthorized))
        }
    }

    @Test func leHandoffNePorteQuUneAdresseHttps() {
        #expect(ClocheSurLiPhone.adresse(ClocheSurLiPhone.userInfo(adresse)) == adresse)
        #expect(ClocheSurLiPhone.adresse(["adresse": "http://tilleuls.exemple"]) == nil)
        #expect(ClocheSurLiPhone.adresse(nil) == nil)
    }
}

/// Un serveur de cloche : une alerte, ou le statut demandé ; il garde ce qu'il a reçu.
private final class TransportCloche: ClientTransport, @unchecked Sendable {
    let statut: HTTPResponse.Status
    var autorisation: String?
    var chemin: String?
    var hote: String?

    init(statut: HTTPResponse.Status) {
        self.statut = statut
    }

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws
        -> (HTTPResponse, HTTPBody?)
    {
        autorisation = request.headerFields[.authorization]
        chemin = request.path
        hote = baseURL.host()
        guard statut == .ok else { return (HTTPResponse(status: statut), nil) }
        let json = """
            [{"id": 7, "type": "ticket_update", "titre": "Fuite", "corps": "<p>Eau</p>", "lue": false,
              "urgente": true, "cree_le": "2026-11-18T10:00:00"}]
            """
        var reponse = HTTPResponse(status: .ok)
        reponse.headerFields[.contentType] = "application/json"
        return (reponse, HTTPBody(json))
    }
}
