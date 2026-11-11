// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import CryptoKit
import Foundation

/// Les pièces jointes ouvertes, en fichiers locaux : Coup d'œil (QuickLook) ne lit qu'un
/// fichier sur le disque. Chacune se lit UNE fois par lancement — par la session de son
/// installation (`ServiceCoproFirst.fichierProtege`) — puis se rouvre sans réseau.
///
/// Le fichier s'écrit sous `tmp/pieces/<empreinte de l'adresse>/<nom montré>` : deux
/// « devis.pdf » de deux affaires ne s'écrasent pas, et Coup d'œil titre la pièce par
/// son nom lisible. Protégé tant que l'appareil est verrouillé (`Fichiers.ecrire`).
actor PiecesLocales {
    static let partagees = PiecesLocales()

    private var lues: [String: URL] = [:]

    /// Le fichier local de chaque pièce, dans l'ordre demandé ; lues en parallèle.
    func fichiers(
        _ chemins: [String], dans installation: Installation, service: any ServiceCoproFirst
    ) async throws -> [URL] {
        try await withThrowingTaskGroup(of: (Int, URL).self) { groupe in
            for (rang, chemin) in chemins.enumerated() {
                let cle = Self.cle(chemin, installation)
                if let deja = lues[cle], FileManager.default.fileExists(atPath: deja.path()) {
                    groupe.addTask { (rang, deja) }
                    continue
                }
                groupe.addTask {
                    let donnees = try await service.fichierProtege(chemin, dans: installation)
                    let fichier = try Fichiers.ecrire(
                        donnees, sous: ["pieces", cle], nom: Fichiers.nomAffiche(chemin))
                    return (rang, fichier)
                }
            }
            var urls = [URL?](repeating: nil, count: chemins.count)
            for try await (rang, url) in groupe {
                urls[rang] = url
                lues[Self.cle(chemins[rang], installation)] = url
            }
            return urls.compactMap(\.self)
        }
    }

    /// L'empreinte de l'adresse entière (hôte + chemin) : un nom de dossier sûr et stable.
    private static func cle(_ chemin: String, _ installation: Installation) -> String {
        let adresse = URL(string: chemin, relativeTo: installation.adresse)?.absoluteString ?? chemin
        return SHA256.hash(data: Data(adresse.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
    }
}
