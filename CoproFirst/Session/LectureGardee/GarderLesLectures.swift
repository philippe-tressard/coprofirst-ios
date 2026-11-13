// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import HTTPTypes
import OpenAPIRuntime

extension LectureGardee {
    /// CE QUI EST GARDÉ, et rien d'autre : la liste blanche des lectures (#101). Une
    /// route absente d'ici n'est jamais écrite sur l'appareil.
    ///
    /// Aucune route de l'administration ni de l'Espace CS — choix prudent, **à confirmer
    /// par Philippe**. `scripts/verifier-lecture-gardee.py` relit cette liste contre le
    /// contrat : une route d'écriture, ou une route de l'administration hors de
    /// l'exception déclarée ci-dessous, fait échouer le dépôt.
    static let operations: Set<String> = [
        // Le fil (tableau de bord).
        Operations.GetFlux.id,
        // Les affaires : la liste, ce qu'il faut pour la lire, et le détail.
        Operations.GetTickets.id,
        Operations.GetTicketsReferentiels.id,
        Operations.GetLotsMesPerimetres.id,
        Operations.GetTicketsTicketId.id,
        Operations.GetTicketsTicketIdEvolutions.id,
        Operations.GetTicketsTicketIdMessages.id,
        // Le profil du compte dans la résidence.
        Operations.GetAuthMe.id,
        // L'annuaire de la résidence (conseil syndical, syndic) — voir `sousAdmin`.
        Operations.GetAdminAnnuaire.id,
        // Un document déjà ouvert.
        Operations.GetDocumentsDocIdTélécharger.id,
    ]

    /// La seule route gardée dont le chemin commence par `/admin` : l'annuaire que TOUT
    /// résident lit au menu Annuaire (le serveur l'a rangé sous `/admin`, il ne demande
    /// aucun rôle d'administration). L'annuaire de l'Espace CS (`…/annuaire/cs`) n'y est pas.
    static let sousAdmin: Set<String> = [Operations.GetAdminAnnuaire.id]

    /// Ce qui part encore pendant la consultation : la session elle-même — la rouvrir
    /// au retour du réseau, ou la fermer (la déconnexion efface de toute façon).
    static let horsConsultation: Set<String> = [
        Operations.PostAuthRefresh.id, Operations.PostAuthLogin.id, Operations.PostAuthLogout.id,
    ]

    /// La clé d'une lecture : sa route et son chemin servi (identifiant et requête compris).
    static func cle(_ operation: String, _ requete: HTTPRequest) -> String {
        "\(operation) \(requete.path ?? "")"
    }

    /// La clé d'un fichier protégé (`/uploads/…` : photo, pièce jointe), lu hors du client généré.
    static func cleFichier(_ chemin: String) -> String { "fichier \(chemin)" }
}

/// LA porte des lectures gardées, glissée entre le client généré et le transport :
/// toute route du contrat y passe, sans qu'aucun service de menu n'ait à le savoir.
///
/// - **En ligne** : une lecture de la liste blanche qui réussit est gardée ; un 401
///   resté refusé après le renouvellement (#81) efface tout ce qui est gardé de l'hôte ;
///   un 403 ou un 404 retire la lecture que ce compte ne peut plus ouvrir.
/// - **En consultation** (entré sans réseau) : une lecture gardée est servie telle que
///   le serveur l'avait servie ; TOUT le reste — une écriture, une lecture non gardée —
///   est refusé ici, `ErreurService.horsLigne`, avant de partir. Agir hors ligne est
///   hors du lot : sans clé d'idempotence côté serveur, un geste pourrait partir deux fois.
/// - Une connexion ou un renouvellement accepté referme la consultation.
struct GarderLesLectures: ClientMiddleware {
    let hote: String
    let lectures: LecturesGardees

    func intercept(
        _ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let cle =
            request.method == .get && LectureGardee.operations.contains(operationID)
            ? LectureGardee.cle(operationID, request) : nil
        let session = LectureGardee.horsConsultation.contains(operationID)
        if lectures.enConsultation(hote), !session {
            guard let cle, let lue = lectures.lire(cle, de: hote) else { throw ErreurService.horsLigne }
            var reponse = HTTPResponse(status: .ok)
            if let type = lue.type { reponse.headerFields[.contentType] = type }
            return (reponse, HTTPBody(lue.corps))
        }
        let (reponse, corps) = try await next(request, body, baseURL)
        if session, reponse.status == .ok, operationID != Operations.PostAuthLogout.id {
            lectures.quitterLaConsultation(hote)
        }
        guard let cle else { return (reponse, corps) }
        switch reponse.status.code {
        case 200:
            guard let corps, lectures.garde(hote), Self.tient(corps) else { return (reponse, corps) }
            let donnees = try await Data(collecting: corps, upTo: LectureGardee.plafond)
            lectures.garder(donnees, type: reponse.headerFields[.contentType], cle: cle, de: hote)
            return (reponse, HTTPBody(donnees))
        case 401:
            lectures.effacer(hote)
        case 403, 404:
            lectures.retirer(cle, de: hote)
        default:
            break
        }
        return (reponse, corps)
    }

    /// Un corps dont la taille annoncée dépasse le plafond passe sans être gardé.
    private static func tient(_ corps: HTTPBody) -> Bool {
        if case .known(let taille) = corps.length { taille <= Int64(LectureGardee.plafond) } else { true }
    }
}
