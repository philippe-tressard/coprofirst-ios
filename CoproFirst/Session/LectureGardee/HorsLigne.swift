// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

// Ce que le hors ligne dit et combien de temps il garde, écrit une fois : pour l'iPhone (#101)
// et pour l'Apple Watch, qui compile ce fichier nommément (`project.yml`, #226).

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

/// La résidence ouverte sans réseau, sur sa dernière lecture gardée (#101).
struct ConsultationHorsLigne: Equatable, Sendable {
    /// La dernière lecture fraîche de cette résidence.
    let aJourAu: Date

    /// « Hors ligne — à jour au 10/11/2026 à 14:32 » : d'où viennent les données.
    var phrase: String {
        "Hors ligne — à jour au \(FormatsDuSite.dateCourte(aJourAu)) à \(FormatsDuSite.heure(aJourAu))"
    }
}

/// Les mots de la consultation hors ligne, écrits une fois.
enum TextesHorsLigne {
    /// Sous la date : pourquoi les gestes sont grisés.
    static let consultationSeule = "Consultation seule : les gestes reviennent avec le réseau."
    /// Ce que VoiceOver lit sur un geste désactivé.
    static let raison = "Indisponible hors ligne : ce geste revient avec le réseau."
    /// Le bandeau d'un appareil qui perd le réseau, l'app ouverte.
    static let peutDater = "Hors ligne — ce qui est affiché peut dater."
    /// Une lecture trop ancienne vient d'être effacée : rien à ouvrir sans réseau.
    static let perimee =
        "Vous êtes hors ligne, et la dernière lecture gardée sur cet appareil datait de plus de "
        + "\(LectureGardee.joursMax) jours : elle a été effacée. Retrouvez du réseau pour rouvrir votre espace."
}
