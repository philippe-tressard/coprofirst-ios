// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

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

/// Ce que donne l'entrée sans réseau.
enum EntreeHorsLigne: Equatable {
    /// La dernière lecture est ouverte, en consultation.
    case ouverte
    /// Une lecture trop ancienne vient d'être effacée : l'écran le dit.
    case perimee
    /// Rien à ouvrir : l'échec de la reprise se dit comme avant.
    case impossible
}

extension Parcours {
    /// La reprise de la session (`service.reprendre`) vient d'échouer : si c'est faute
    /// de réseau et qu'une lecture est gardée, la résidence s'ouvre en consultation.
    ///
    /// Ne s'appelle QUE sur l'échec de `reprendre` : `horsLigne` et `injoignable` n'y
    /// viennent que du serveur, donc APRÈS la lecture du Trousseau — Face ID est passé.
    /// Un Face ID annulé (`sessionExpiree`) n'ouvre rien.
    func entrerHorsLigne(_ installation: Installation, apres erreur: any Error) -> EntreeHorsLigne {
        let cause = ErreurService.depuis(erreur)
        guard cause == .horsLigne || cause == .injoignable, let service = service.horsLigne else {
            return .impossible
        }
        switch service.consulterHorsLigne(installation) {
        case .gardee(let date):
            ouvrir(installation, consultation: ConsultationHorsLigne(aJourAu: date))
            return .ouverte
        case .perimee:
            return .perimee
        case .aucune:
            return .impossible
        }
    }

    /// Le réseau est revenu : la session se rouvre, sans redemander Face ID, et les
    /// écrans relisent tout (`RacineView` reconstruit l'espace quand la consultation
    /// finit). Un refus du serveur (compte révoqué, jeton expiré) a tout effacé : retour
    /// à la connexion. Toujours sans réseau : la consultation continue.
    func reprendreEnLigne() async {
        guard let installation = ouverte, consultation != nil, !repriseEnCours,
            let service = service.horsLigne
        else { return }
        repriseEnCours = true
        defer { repriseEnCours = false }
        do {
            try await service.reprendreEnLigne(installation)
            guard ouverte == installation else { return }
            consultation = nil
            if let push { await push.residenceOuverte(installation) }
        } catch {
            guard ErreurService.depuis(error) == .sessionExpiree, ouverte == installation else { return }
            revenirALaConnexion(installation, avis: ErreurService.sessionExpiree.phrase)
        }
    }

    /// Au lancement : rien ne reste d'une lecture périmée, ni d'une résidence dont la
    /// session n'est plus gardée.
    func purgerLesLectures() {
        service.horsLigne?.purgerLesLectures(sauf: connues.liste.filter { service.aUneSessionGardee($0) })
    }
}
