// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Lire un fichier servi : la SEULE écriture de ce geste (#32). Un document, un
/// rapport de diagnostic, toute route qui sert un `FileResponse` passe par ici.
extension ServiceAPI {
    /// Une route qui sert un FICHIER (`FileResponse`) que le contrat déclare en JSON :
    /// le client généré le refuse, et l'erreur porte le corps — lu sur un 200 seulement
    /// (le contrat devrait déclarer le type servi : coprofirst#2505).
    ///
    /// `appel` lance la requête du client généré et lève `ErreurService.depuisLecture`
    /// sur une réponse non documentée (403, 404…). Le fichier s'écrit sous un nom sûr,
    /// dans `tmp/documents/`, protégé tant que l'appareil est verrouillé.
    static func fichierServi(
        nom: String?, defaut: String, appel: () async throws -> Void
    ) async throws -> URL {
        let donnees: Data
        do {
            try await appel()
            // Le client a décodé du JSON là où un fichier était attendu.
            throw ErreurService.inattendue(200)
        } catch let erreur as ErreurService {
            throw erreur
        } catch {
            guard let fichier = try await ClientCoproFirst.fichierServi(error) else {
                throw ErreurService.depuis(ClientCoproFirst.cause(error))
            }
            donnees = fichier
        }
        let dossier = FileManager.default.temporaryDirectory.appending(path: "documents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let fichier = dossier.appending(path: Fichiers.nomSur(nom, defaut: defaut))
        try donnees.write(to: fichier, options: [.atomic, .completeFileProtection])
        return fichier
    }
}

/// Les noms et natures des fichiers lus par l'app.
enum Fichiers {
    /// Un nom de fichier sûr pour le disque : sans chemin, sans caractère de contrôle.
    static func nomSur(_ nom: String?, defaut: String) -> String {
        let propre = (nom ?? "")
            .components(separatedBy: CharacterSet(charactersIn: "/\\:").union(.controlCharacters))
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.whitespaces))
        return propre.isEmpty ? defaut : propre
    }

    static func estImage(_ chemin: String) -> Bool {
        ["jpg", "jpeg", "png", "heic", "webp", "gif"].contains((chemin as NSString).pathExtension.lowercased())
    }
}
