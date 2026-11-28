// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Les noms et natures des fichiers lus par l'app — compilés aussi par l'écran de hall, qui
/// range les photos du Fil (#429) sans lire de fichier servi (`FichierServi.swift`).
enum Fichiers {
    /// Un nom de fichier sûr pour le disque : sans chemin, sans caractère de contrôle.
    static func nomSur(_ nom: String?, defaut: String) -> String {
        let propre = (nom ?? "")
            .components(separatedBy: CharacterSet(charactersIn: "/\\:").union(.controlCharacters))
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.whitespaces))
        return propre.isEmpty ? defaut : propre
    }

    /// Une image affichable en vignette — la liste du site (`FichiersDuSite`, générée).
    static func estImage(_ chemin: String) -> Bool {
        FichiersDuSite.extensionsImage.contains(extensionDe(chemin).lowercased())
    }

    /// Le nom montré d'un fichier servi (`nomFichier` du site) : le dernier segment de
    /// l'URL, décodé, sans le préfixe que le serveur ajoute au téléversement.
    static func nomAffiche(_ chemin: String) -> String {
        let segment = chemin.split(separator: "?").first.map(String.init) ?? chemin
        let brut = segment.split(separator: "/").last.map(String.init) ?? segment
        let base = brut.removingPercentEncoding ?? brut
        let prefixe = FichiersDuSite.longueurPrefixe
        guard base.count > prefixe + 1, base.dropFirst(prefixe).first == "_",
            base.prefix(prefixe).allSatisfy(\.isHexDigit)
        else { return base }
        let reste = String(base.dropFirst(prefixe + 1))
        return reste.isEmpty ? base : reste
    }

    /// « PDF », « WORD », « EXCEL » — le type montré (`typeFichier` du site).
    static func typeAffiche(_ chemin: String) -> String {
        let ext = extensionDe(nomAffiche(chemin)).uppercased()
        return ext.isEmpty ? "FICHIER" : FichiersDuSite.familles[ext] ?? ext
    }

    /// Le nom montré, sans son extension (`nomSansExtension` du site).
    static func nomSansExtension(_ chemin: String) -> String {
        let nom = nomAffiche(chemin)
        let ext = extensionDe(nom)
        return ext.isEmpty ? nom : String(nom.dropLast(ext.count + 1))
    }

    /// La protection de TOUT fichier que l'app écrit : illisible tant que l'appareil est
    /// verrouillé (`.complete`), et jamais à moitié écrit.
    static let protection: Data.WritingOptions = [.atomic, .completeFileProtection]

    /// Écrire un fichier lu dans `<racine>/<dossiers…>/<nom>` — `tmp/` par défaut, le
    /// magasin des lectures gardées sinon (#101) —, protégé tant que l'appareil est
    /// verrouillé : la seule écriture sur disque d'un fichier servi.
    static func ecrire(
        _ donnees: Data, sous dossiers: [String], nom: String, racine: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        var dossier = racine
        for sous in dossiers { dossier.append(path: nomSur(sous, defaut: "f"), directoryHint: .isDirectory) }
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let fichier = dossier.appending(path: nomSur(nom, defaut: "fichier"))
        try donnees.write(to: fichier, options: protection)
        return fichier
    }

    /// Les copies temporaires des fichiers ouverts (documents, pièces jointes), pour
    /// Coup d'œil : effacées à la déconnexion, avec la lecture gardée (#101).
    static let copies = ["documents", "pieces"]

    static func effacerLesCopies() {
        for dossier in copies {
            try? FileManager.default.removeItem(at: FileManager.default.temporaryDirectory.appending(path: dossier))
        }
    }

    /// L'extension d'un nom (« pdf »), vide sans point ou pour un nom qui commence par un point.
    private static func extensionDe(_ nom: String) -> String {
        guard let point = nom.lastIndex(of: "."), point != nom.startIndex else { return "" }
        let ext = nom[nom.index(after: point)...]
        return ext.contains("/") ? "" : String(ext)
    }
}
