// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// La dernière cloche lue en ligne, gardée sur la montre pour être relue sans réseau (#226,
/// lot 3), comme la consultation hors ligne de l'iPhone (#101) et la montre Wear OS : la même
/// durée (`LectureGardee.joursMax`), le même libellé (`ConsultationHorsLigne`).
struct ClocheGardee: Codable, Equatable, Sendable {
    /// La résidence lue : une cloche gardée ne se montre que pour elle.
    let adresse: URL
    let alertes: [NotificationRecue]
    let aJourAu: Date
}

/// Où la montre garde sa dernière cloche.
protocol GardeDeLaCloche: Sendable {
    func lire() -> ClocheGardee?
    func garder(_ cloche: ClocheGardee)
    func effacer()
}

extension GardeDeLaCloche {
    /// La cloche gardée de CETTE résidence, si elle vaut encore ; une lecture plus vieille que
    /// `LectureGardee.joursMax` s'efface, comme sur l'iPhone.
    func consultable(pour adresse: URL, maintenant: Date = .now) -> ClocheGardee? {
        guard let gardee = lire(), gardee.adresse == adresse else { return nil }
        guard maintenant.timeIntervalSince(gardee.aJourAu) <= LectureGardee.dureeMax else {
            effacer()
            return nil
        }
        return gardee
    }
}

/// Sur le disque de la montre : `Application Support`, exclu des sauvegardes, chiffré jusqu'au
/// premier déverrouillage (le rafraîchissement d'arrière-plan doit pouvoir l'écrire). Une
/// entrée illisible se lit comme aucune.
struct GardeSurDisque: GardeDeLaCloche {
    let dossier: URL

    static var parDefaut: GardeSurDisque? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            .map { GardeSurDisque(dossier: $0.appending(path: "cloche", directoryHint: .isDirectory)) }
    }

    private var fichier: URL { dossier.appending(path: "cloche-gardee.json") }

    func lire() -> ClocheGardee? {
        (try? Data(contentsOf: fichier)).flatMap { try? JSONDecoder().decode(ClocheGardee.self, from: $0) }
    }

    func garder(_ cloche: ClocheGardee) {
        guard let donnees = try? JSONEncoder().encode(cloche) else { return }
        do {
            try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
            var exclu = dossier
            var valeurs = URLResourceValues()
            valeurs.isExcludedFromBackup = true
            try exclu.setResourceValues(valeurs)
            try donnees.write(to: fichier, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            // Rien de gardé : sans réseau, la montre dira « injoignable ».
        }
    }

    func effacer() {
        try? FileManager.default.removeItem(at: fichier)
    }
}

/// En mémoire : les tests, la simulation, et une montre sans dossier d'application.
final class GardeEnMemoire: GardeDeLaCloche, @unchecked Sendable {
    private var cloche: ClocheGardee?
    private let verrou = NSLock()

    init(_ cloche: ClocheGardee? = nil) {
        self.cloche = cloche
    }

    func lire() -> ClocheGardee? { verrou.withLock { cloche } }
    func garder(_ cloche: ClocheGardee) { verrou.withLock { self.cloche = cloche } }
    func effacer() { verrou.withLock { cloche = nil } }
}

extension ResumeCloche {
    /// Ce que le widget dit d'une lecture de la montre : en ligne ou hors ligne, la même cloche.
    init?(_ lecture: LectureCloche) {
        switch lecture {
        case .enCours: return nil
        case .injoignable: self = .injoignable
        case .lue(let cloche), .horsLigne(let cloche, _):
            self = .compte(nonLues: cloche.nonLues.count, urgentes: cloche.urgentes)
        }
    }
}
