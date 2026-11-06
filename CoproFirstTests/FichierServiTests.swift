// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import CoproFirst

// La lecture d'un fichier servi (#32) : une seule fonction, pour les documents comme
// pour les rapports. Le client généré refuse le fichier (le contrat annonce du JSON) :
// son erreur porte la réponse, que l'on rejoue ici sans réseau.

/// L'erreur que lève le client généré devant un fichier servi.
private func refusDuClient(statut: HTTPResponse.Status, corps: String?) -> ClientError {
    ClientError(
        operationID: "getDocumentsDocIdTélécharger", operationInput: 0,
        response: HTTPResponse(status: statut), responseBody: corps.map { HTTPBody($0) },
        causeDescription: "type de contenu inattendu", underlyingError: CocoaError(.coderInvalidValue))
}

@Test func unFichierServiEn200SEcritSousUnNomSur() async throws {
    let fichier = try await ServiceAPI.fichierServi(nom: "../PV AG 2026.pdf", defaut: "document-7") {
        throw refusDuClient(statut: .ok, corps: "%PDF-1.7")
    }
    defer { try? FileManager.default.removeItem(at: fichier) }
    #expect(fichier.lastPathComponent == "-PV AG 2026.pdf", "sans chemin")
    #expect(fichier.deletingLastPathComponent().lastPathComponent == "documents")
    #expect(try String(contentsOf: fichier, encoding: .utf8) == "%PDF-1.7")
}

@Test func unFichierSansNomPrendLeNomParDefaut() async throws {
    let fichier = try await ServiceAPI.fichierServi(nom: nil, defaut: "rapport-3") {
        throw refusDuClient(statut: .ok, corps: "x")
    }
    defer { try? FileManager.default.removeItem(at: fichier) }
    #expect(fichier.lastPathComponent == "rapport-3")
}

@Test func unFichierRefuseSeDitIntrouvable() async {
    // Le 404 n'est pas documenté : le client le rend tel quel, l'appelant le lève.
    await #expect(throws: ErreurService.introuvable) {
        _ = try await ServiceAPI.fichierServi(nom: "x.pdf", defaut: "d") {
            throw ErreurService.depuisLecture(404)
        }
    }
}

@Test func unCorpsAbsentNEstPasUnFichier() async {
    await #expect(throws: (any Error).self) {
        _ = try await ServiceAPI.fichierServi(nom: "x.pdf", defaut: "d") {
            throw refusDuClient(statut: .ok, corps: nil)
        }
    }
    // Hors d'un 200, le corps n'est jamais pris pour le fichier.
    await #expect(throws: (any Error).self) {
        _ = try await ServiceAPI.fichierServi(nom: "x.pdf", defaut: "d") {
            throw refusDuClient(statut: .internalServerError, corps: "<html>")
        }
    }
}

@Test func uneReponseDecodeeEnJSONNEstPasUnFichier() async {
    await #expect(throws: ErreurService.inattendue(200)) {
        _ = try await ServiceAPI.fichierServi(nom: "x.pdf", defaut: "d") {}
    }
}
