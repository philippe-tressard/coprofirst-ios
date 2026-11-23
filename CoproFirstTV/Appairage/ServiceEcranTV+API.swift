// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import OpenAPIRuntime

/// L'écran de hall par le client GÉNÉRÉ (contrat 2.6.0), sur une session éphémère : l'écran
/// n'a ni compte ni cookie. Son jeton part en `Bearer` (`JetonAppareil`) sur le seul client des
/// routes de sa portée.
struct ServiceEcranAPI: ServiceEcranTV, LitLesRefus {
    /// La plus grande image qu'une affiche porte : une photo téléversée sur le site.
    private static let plafondImage = 20 * 1024 * 1024

    private func client(_ adresse: URL, jeton: JetonMasque? = nil) -> Client {
        ClientCoproFirst.client(
            installation: adresse, session: URLSession(configuration: .ephemeral),
            middlewares: jeton.map { [JetonAppareil($0)] } ?? [])
    }

    func demander(_ adresse: URL) async throws -> DemandeAppairageTV {
        switch try await appeler({ try await client(adresse).postEcransAppairage() }) {
        case .ok(let ok):
            let lu = try ok.body.json
            return DemandeAppairageTV(
                codeAppareil: lu.codeAppareil, codeCourt: lu.codeCourt, expireDans: lu.expireDans,
                intervalle: lu.intervalle)
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func interroger(_ codeAppareil: String, _ adresse: URL) async throws -> ReponseAppairage {
        let corps = Components.Schemas.Interrogation(codeAppareil: codeAppareil)
        switch try await appeler({ try await client(adresse).postEcransAppairageJeton(body: .json(corps)) }) {
        case .ok(let ok):
            let lu = try ok.body.json
            return .jeton(JetonMasque(lu.jeton), expireLe: lu.expireLe)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, let reponse):
            // 400 et son `detail` : ce qu'il faut faire ensuite (RFC 8628 §3.5).
            let refus = await Self.refus(statut, reponse)
            if statut == 400, let suite = ReponseAppairage.depuis(detail: refus.phraseDuServeur) { return suite }
            throw refus
        }
    }

    func affiches(_ adresse: URL, jeton: JetonMasque) async throws -> [AfficheHall] {
        switch try await appeler({ try await client(adresse, jeton: jeton).getEcransMoiAffiches() }) {
        case .ok(let ok):
            return try ok.body.json.map {
                AfficheHall(
                    id: $0.id, titre: $0.titre, message: $0.message, images: $0.images.count, creeLe: $0.creeeLe)
            }
        case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
        }
    }

    func image(_ affiche: Int, rang: Int, _ adresse: URL, jeton: JetonMasque) async throws -> Data {
        // Le contrat déclare `application/octet-stream`, le serveur sert le type de l'image :
        // le client généré refuse, et son erreur porte le corps — lu sur un 200 seulement.
        do {
            let sortie = try await client(adresse, jeton: jeton).getEcransMoiAffichesAfficheIdImagesRang(
                path: .init(afficheId: affiche, rang: rang))
            switch sortie {
            case .ok(let ok):
                return try await Data(collecting: ok.body.binary, upTo: Self.plafondImage)
            case .unprocessableContent: throw ErreurService.inattendue(422)
            case .undocumented(let statut, let reponse): throw await Self.refus(statut, reponse)
            }
        } catch let erreur as ErreurService {
            throw erreur
        } catch {
            if let donnees = try await ClientCoproFirst.fichierServi(error, plafond: Self.plafondImage) {
                return donnees
            }
            throw ErreurService.depuis(ClientCoproFirst.cause(error))
        }
    }

    /// L'appel généré ; une erreur de transport devient la phrase de l'iPhone.
    private func appeler<T>(_ appel: () async throws -> T) async throws -> T {
        do { return try await appel() } catch { throw ErreurService.depuis(ClientCoproFirst.cause(error)) }
    }
}
