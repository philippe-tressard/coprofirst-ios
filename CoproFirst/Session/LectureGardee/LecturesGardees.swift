// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import CryptoKit
import Foundation

/// La consultation hors ligne (#101) : la dernière lecture de chaque résidence, gardée
/// sur l'appareil pour être relue sans réseau — jamais pour agir.
enum LectureGardee {
    /// La durée maximale d'une lecture gardée, en jours. Au-delà, sans lecture fraîche,
    /// elle est effacée : un compte révoqué ne garde pas ses données indéfiniment hors
    /// ligne. **Proposition du ticket (#101), à confirmer par Philippe.**
    static let joursMax = 7
    static var dureeMax: TimeInterval { TimeInterval(joursMax) * 86_400 }

    /// La taille maximale d'une réponse gardée : celle d'un fichier servi
    /// (`ClientCoproFirst.fichierServi`). Au-delà, la réponse passe sans être gardée.
    static let plafond = 50 * 1024 * 1024
}

/// Ce que l'appareil garde d'une résidence, au moment d'y entrer sans réseau.
enum LectureDisponible: Equatable, Sendable {
    /// Une lecture gardée, et la date de sa dernière mise à jour.
    case gardee(Date)
    /// Une lecture plus vieille que `LectureGardee.joursMax` : elle vient d'être effacée.
    case perimee
    case aucune
}

/// Une réponse gardée : son corps, son type, sa date.
struct LectureLue: Equatable, Sendable {
    let corps: Data
    let type: String?
    let date: Date
}

/// LE magasin des lectures gardées — la seule porte du disque : aucun écran, aucun
/// service de menu ne lit ni n'écrit ces fichiers.
///
/// - Un dossier par résidence (par hôte), nommé par l'empreinte de l'hôte : rien ne se
///   croise d'une résidence à l'autre, et `effacer` retire le dossier entier.
/// - Chaque fichier s'écrit par LA porte des fichiers de l'app (`Fichiers.ecrire`) :
///   protection `.complete`, illisible tant que l'appareil est verrouillé. Le magasin est
///   exclu des sauvegardes (iCloud, Finder) ; si l'exclusion ne tient pas, rien ne s'écrit.
/// - La date de chaque lecture vit dans l'index du dossier (`dates`), écrit de même :
///   aucune date de fichier n'est lue.
/// - Rien n'est gardé pour une résidence dont la session n'est pas gardée au Trousseau
///   (`sessionGardee`) : sans Face ID pour la rouvrir, cette lecture ne servirait à rien.
/// - Aucun jeton, aucun mot de passe, aucun cookie : le corps d'une réponse de LECTURE
///   (`LectureGardee.operations`) et son type, rien de ses en-têtes ni de la requête.
final class LecturesGardees: @unchecked Sendable {
    /// Écrire un fichier sous un dossier du magasin : `Fichiers.ecrire` en vrai ; un
    /// double, pour éprouver un disque qui refuse.
    typealias Ecriture = @Sendable (Data, _ dossier: String, _ nom: String) throws -> Void

    private let racine: URL
    private let horloge: @Sendable () -> Date
    private let sessionGardee: @Sendable (String) -> Bool
    private let ecrire: Ecriture
    private let verrou = NSLock()
    /// Les résidences ouvertes sans réseau (en mémoire : un lancement repart en ligne).
    private var consultations: Set<String> = []

    /// Le nom de l'index des dates, dans le dossier d'un hôte.
    private static let index = "dates"

    init(
        racine: URL, horloge: @escaping @Sendable () -> Date = { .now },
        sessionGardee: @escaping @Sendable (String) -> Bool, ecrire: Ecriture? = nil
    ) {
        self.racine = racine
        self.horloge = horloge
        self.sessionGardee = sessionGardee
        self.ecrire = ecrire ?? { _ = try Fichiers.ecrire($0, sous: [$1], nom: $2, racine: racine) }
    }

    /// Le magasin de l'app : `Application Support/LecturesGardees` — ni le dossier
    /// temporaire ni les caches (iOS les vide sans prévenir), ni les réglages.
    static let racineAppareil = URL.applicationSupportDirectory.appending(
        path: "LecturesGardees", directoryHint: .isDirectory)
    static let appareil = LecturesGardees(racine: racineAppareil, sessionGardee: { Trousseau.contient(pour: $0) })

    // MARK: - Garder, relire

    /// Cet hôte garde-t-il ses lectures ? Seulement si sa session est gardée au Trousseau.
    func garde(_ hote: String) -> Bool { sessionGardee(hote) }

    /// Garde le corps d'une lecture réussie. Sans session gardée pour cet hôte, ou si
    /// la protection ne peut pas être posée, rien n'est écrit.
    func garder(_ corps: Data, type: String?, cle: String, de hote: String) {
        guard garde(hote) else { return }
        verrou.withLock {
            do {
                try preparer(hote)
                let nom = Self.empreinte(cle)
                try ecrire(try PropertyListEncoder().encode(Enveloppe(type: type, corps: corps)), dossierDe(hote), nom)
                var dates = lireIndex(hote)
                dates[nom] = horloge()
                try ecrireIndex(dates, hote)
            } catch {
                // Écriture refusée (appareil verrouillé, disque plein) : rien n'est gardé.
            }
        }
    }

    /// La lecture gardée sous cette clé — `nil` si elle manque ou si elle a passé la
    /// durée maximale (elle est alors effacée).
    func lire(_ cle: String, de hote: String) -> LectureLue? {
        verrou.withLock {
            let nom = Self.empreinte(cle)
            guard let date = lireIndex(hote)[nom] else { return nil }
            guard !perime(date) else {
                oublier([nom], hote)
                return nil
            }
            guard let donnees = try? Data(contentsOf: dossier(hote).appending(path: nom)),
                let enveloppe = try? PropertyListDecoder().decode(Enveloppe.self, from: donnees)
            else { return nil }
            return LectureLue(corps: enveloppe.corps, type: enveloppe.type, date: date)
        }
    }

    /// Retire UNE lecture : le serveur ne la sert plus à ce compte (403, 404).
    func retirer(_ cle: String, de hote: String) {
        verrou.withLock { oublier([Self.empreinte(cle)], hote) }
    }

    // MARK: - Entrer sans réseau, en sortir

    /// Ce qui est gardé pour cet hôte. Une lecture gardée ouvre la CONSULTATION : tant
    /// qu'elle dure, rien ne part vers cet hôte hors de sa session (`GarderLesLectures`).
    /// Une lecture périmée est effacée, et dite.
    func consulter(_ hote: String) -> LectureDisponible {
        verrou.withLock {
            guard let derniere = lireIndex(hote).values.max() else { return .aucune }
            guard !perime(derniere) else {
                try? FileManager.default.removeItem(at: dossier(hote))
                return .perimee
            }
            consultations.insert(hote)
            return .gardee(derniere)
        }
    }

    func enConsultation(_ hote: String) -> Bool { verrou.withLock { consultations.contains(hote) } }

    /// La session de cet hôte est rouverte : ses lectures repartent du serveur.
    func quitterLaConsultation(_ hote: String) { verrou.withLock { _ = consultations.remove(hote) } }

    // MARK: - Effacer

    /// Efface tout ce qui est gardé de cet hôte — la déconnexion, une session que le
    /// serveur refuse.
    func effacer(_ hote: String) {
        verrou.withLock {
            consultations.remove(hote)
            try? FileManager.default.removeItem(at: dossier(hote))
        }
    }

    /// Au lancement : efface les lectures périmées, et celles des hôtes dont la session
    /// n'est plus gardée (`gardes`) — rien ne reste d'une résidence où l'on n'est pas connecté.
    func purger(sauf gardes: Set<String>) {
        verrou.withLock {
            let attendus = Dictionary(uniqueKeysWithValues: gardes.map { (Self.empreinte($0), $0) })
            let dossiers = try? FileManager.default.contentsOfDirectory(at: racine, includingPropertiesForKeys: nil)
            for dossier in dossiers ?? [] {
                guard let hote = attendus[dossier.lastPathComponent] else {
                    try? FileManager.default.removeItem(at: dossier)
                    continue
                }
                let dates = lireIndex(hote)
                let presents = (try? FileManager.default.contentsOfDirectory(atPath: dossier.path)) ?? []
                // Une lecture périmée, ou un fichier que l'index ne date pas : effacés.
                let aOublier = presents.filter { $0 != Self.index && dates[$0].map(perime) ?? true }
                oublier(aOublier + dates.keys.filter { !presents.contains($0) }, hote)
            }
        }
    }

    // MARK: - Le disque

    private struct Enveloppe: Codable {
        let type: String?
        let corps: Data
    }

    /// Le dossier d'un hôte, par son empreinte (aucun nom de résidence dans un chemin).
    func dossier(_ hote: String) -> URL {
        racine.appending(path: dossierDe(hote), directoryHint: .isDirectory)
    }

    private func dossierDe(_ hote: String) -> String { Self.empreinte(hote) }

    static func empreinte(_ texte: String) -> String {
        SHA256.hash(data: Data(texte.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Crée le dossier de l'hôte sous la protection `.complete`, et exclut le magasin
    /// des sauvegardes. Lève si l'une des deux ne tient pas : rien ne s'écrit alors.
    private func preparer(_ hote: String) throws {
        let dossier = dossier(hote)
        try FileManager.default.createDirectory(
            at: dossier, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        var exclue = URLResourceValues()
        exclue.isExcludedFromBackup = true
        for var chemin in [racine, dossier] {
            try chemin.setResourceValues(exclue)
        }
    }

    private func lireIndex(_ hote: String) -> [String: Date] {
        guard let donnees = try? Data(contentsOf: dossier(hote).appending(path: Self.index)) else { return [:] }
        return (try? PropertyListDecoder().decode([String: Date].self, from: donnees)) ?? [:]
    }

    private func ecrireIndex(_ dates: [String: Date], _ hote: String) throws {
        try ecrire(try PropertyListEncoder().encode(dates), dossierDe(hote), Self.index)
    }

    /// Efface ces lectures et leurs dates ; un index vide emporte le dossier.
    private func oublier(_ noms: [String], _ hote: String) {
        guard !noms.isEmpty else { return }
        var dates = lireIndex(hote)
        for nom in noms {
            try? FileManager.default.removeItem(at: dossier(hote).appending(path: nom))
            dates[nom] = nil
        }
        if dates.isEmpty {
            try? FileManager.default.removeItem(at: dossier(hote))
        } else if (try? ecrireIndex(dates, hote)) == nil {
            // L'index ne s'écrit plus : tout l'hôte s'efface plutôt qu'une lecture mal datée.
            try? FileManager.default.removeItem(at: dossier(hote))
        }
    }

    private func perime(_ date: Date) -> Bool { horloge().timeIntervalSince(date) > LectureGardee.dureeMax }
}
