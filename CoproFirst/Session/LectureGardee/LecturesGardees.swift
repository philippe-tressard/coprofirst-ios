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
/// - Chaque fichier est créé sous la protection `.complete` (illisible tant que
///   l'appareil est verrouillé) et le magasin est exclu des sauvegardes (iCloud,
///   Finder). Si l'une des deux ne peut pas être posée, rien n'est écrit.
/// - Rien n'est gardé pour une résidence dont la session n'est pas gardée au Trousseau
///   (`sessionGardee`) : sans Face ID pour la rouvrir, cette lecture ne servirait à rien.
/// - Aucun jeton, aucun mot de passe, aucun cookie : le corps d'une réponse de LECTURE
///   (`LectureGardee.operations`) et son type, rien de ses en-têtes ni de la requête.
final class LecturesGardees: @unchecked Sendable {
    /// Écrire un fichier : `Data.write` en vrai ; un double, pour éprouver les options.
    typealias Ecriture = @Sendable (Data, URL, Data.WritingOptions) throws -> Void

    /// Les options de TOUTE écriture du magasin.
    static let options: Data.WritingOptions = [.atomic, .completeFileProtection]

    private let racine: URL
    private let horloge: @Sendable () -> Date
    private let sessionGardee: @Sendable (String) -> Bool
    private let ecrire: Ecriture
    private let verrou = NSLock()
    /// Les résidences ouvertes sans réseau (en mémoire : un lancement repart en ligne).
    private var consultations: Set<String> = []

    init(
        racine: URL, horloge: @escaping @Sendable () -> Date = { .now },
        sessionGardee: @escaping @Sendable (String) -> Bool,
        ecrire: @escaping Ecriture = { try $0.write(to: $1, options: $2) }
    ) {
        self.racine = racine
        self.horloge = horloge
        self.sessionGardee = sessionGardee
        self.ecrire = ecrire
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
                let dossier = try preparer(hote)
                let fichier = dossier.appending(path: Self.empreinte(cle))
                let enveloppe = try PropertyListEncoder().encode(Enveloppe(type: type, corps: corps))
                try ecrire(enveloppe, fichier, Self.options)
                try FileManager.default.setAttributes([.modificationDate: horloge()], ofItemAtPath: fichier.path)
            } catch {
                // Écriture refusée (appareil verrouillé, disque plein) : rien n'est gardé.
            }
        }
    }

    /// La lecture gardée sous cette clé — `nil` si elle manque ou si elle a passé la
    /// durée maximale (elle est alors effacée).
    func lire(_ cle: String, de hote: String) -> LectureLue? {
        verrou.withLock {
            let fichier = dossier(hote).appending(path: Self.empreinte(cle))
            guard let date = date(fichier) else { return nil }
            guard !perime(date) else {
                try? FileManager.default.removeItem(at: fichier)
                return nil
            }
            guard let donnees = try? Data(contentsOf: fichier),
                let enveloppe = try? PropertyListDecoder().decode(Enveloppe.self, from: donnees)
            else { return nil }
            return LectureLue(corps: enveloppe.corps, type: enveloppe.type, date: date)
        }
    }

    /// Retire UNE lecture : le serveur ne la sert plus à ce compte (403, 404).
    func retirer(_ cle: String, de hote: String) {
        verrou.withLock {
            try? FileManager.default.removeItem(at: dossier(hote).appending(path: Self.empreinte(cle)))
        }
    }

    // MARK: - Entrer sans réseau, en sortir

    /// Ce qui est gardé pour cet hôte. Une lecture gardée ouvre la CONSULTATION : tant
    /// qu'elle dure, rien ne part vers cet hôte hors de sa session (`GarderLesLectures`).
    /// Une lecture périmée est effacée, et dite.
    func consulter(_ hote: String) -> LectureDisponible {
        verrou.withLock {
            let dates = fichiers(hote).compactMap(date)
            guard let derniere = dates.max() else { return .aucune }
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
            let attendus = Set(gardes.map(Self.empreinte))
            let dossiers = try? FileManager.default.contentsOfDirectory(at: racine, includingPropertiesForKeys: nil)
            for dossier in dossiers ?? [] {
                guard attendus.contains(dossier.lastPathComponent) else {
                    try? FileManager.default.removeItem(at: dossier)
                    continue
                }
                let lectures = try? FileManager.default.contentsOfDirectory(at: dossier, includingPropertiesForKeys: nil)
                for fichier in lectures ?? [] where date(fichier).map(perime) ?? true {
                    try? FileManager.default.removeItem(at: fichier)
                }
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
        racine.appending(path: Self.empreinte(hote), directoryHint: .isDirectory)
    }

    static func empreinte(_ texte: String) -> String {
        SHA256.hash(data: Data(texte.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Crée le dossier de l'hôte sous la protection `.complete`, et exclut le magasin
    /// des sauvegardes. Lève si l'une des deux ne tient pas : rien ne s'écrit alors.
    private func preparer(_ hote: String) throws -> URL {
        let dossier = dossier(hote)
        try FileManager.default.createDirectory(
            at: dossier, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        var exclue = URLResourceValues()
        exclue.isExcludedFromBackup = true
        for var chemin in [racine, dossier] {
            try chemin.setResourceValues(exclue)
        }
        return dossier
    }

    private func fichiers(_ hote: String) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: dossier(hote), includingPropertiesForKeys: nil)) ?? []
    }

    private func date(_ fichier: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: fichier.path))?[.modificationDate] as? Date
    }

    private func perime(_ date: Date) -> Bool { horloge().timeIntervalSince(date) > LectureGardee.dureeMax }
}
