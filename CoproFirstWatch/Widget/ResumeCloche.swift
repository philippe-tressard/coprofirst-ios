// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que le widget de la montre dit de la cloche (#226, périmètre du 16/11/2026), comme la
/// tuile et la complication de Wear OS : « 2 nouvelles alertes · dont 1 urgente », ou un
/// point sur le logo. Ni titre, ni corps, ni nom de résidence : le cadran se voit d'un coup
/// d'œil, par d'autres aussi. Compilé par l'app montre, qui l'écrit, et par son widget, qui
/// le lit (`project.yml`).
enum ResumeCloche: Codable, Equatable, Sendable {
    /// La montre n'est pas reliée (ou la liaison est éteinte).
    case nonReliee
    /// Sans réseau et sans lecture gardée : la résidence ne répond pas.
    case injoignable
    /// Les non lues de la dernière lecture (en ligne ou gardée), et combien sont urgentes.
    case compte(nonLues: Int, urgentes: Int)

    /// La phrase du widget rectangulaire.
    var phrase: String {
        switch self {
        case .nonReliee: TextesMontre.nonReliee
        case .injoignable: TextesMontre.injoignable
        case .compte(let nonLues, let urgentes):
            if nonLues <= 0 {
                TextesMontre.aucuneAlerte
            } else if urgentes <= 0 {
                TextesMontre.nouvellesAlertes(nonLues)
            } else {
                TextesMontre.nouvellesAlertes(nonLues) + Separateur.point + TextesMontre.dontUrgentes(urgentes)
            }
        }
    }

    /// Le point de la complication : du non lu dans la cloche lue. Rien d'autre ne l'allume.
    var pointNonLu: Bool {
        if case .compte(let nonLues, _) = self { nonLues > 0 } else { false }
    }
}

/// Le résumé passe de l'app au widget par l'App Group (`group.fr.coprofirst.app`, enregistré
/// par Philippe le 18/11/2026) : un petit fichier, des nombres seulement. Sans conteneur de
/// groupe (build sans signature), rien ne s'écrit et le widget dit « non reliée ».
enum PartageDuResume {
    static let groupe = "group.fr.coprofirst.app"
    private static let fichier = "resume-cloche.json"

    static var dossier: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupe)
    }

    static func lire(_ dossier: URL? = dossier) -> ResumeCloche {
        guard let dossier, let donnees = try? Data(contentsOf: dossier.appending(path: fichier)),
            let resume = try? JSONDecoder().decode(ResumeCloche.self, from: donnees)
        else { return .nonReliee }
        return resume
    }

    /// `false` : rien n'a pu s'écrire.
    @discardableResult
    static func ecrire(_ resume: ResumeCloche, _ dossier: URL? = dossier) -> Bool {
        guard let dossier, let donnees = try? JSONEncoder().encode(resume) else { return false }
        do {
            try donnees.write(
                to: dossier.appending(path: fichier),
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }
}
