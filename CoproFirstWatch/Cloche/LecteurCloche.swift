// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Observation

/// Lit la cloche d'une source et tient ce que la montre en sait. Une lecture déjà faite
/// reste affichée pendant la suivante : l'écran ne repasse pas par « chargement » à chaque
/// retour au premier plan.
@MainActor @Observable
final class LecteurCloche {
    private(set) var lecture: LectureCloche = .enCours
    private let source: SourceDeLaCloche
    private let garde: any GardeDeLaCloche
    /// Ce que le widget doit dire après la lecture (`Surfaces`).
    private let publier: @MainActor (ResumeCloche) -> Void
    /// Le serveur ne reconnaît plus le jeton : la liaison s'oublie, la montre attend l'iPhone.
    private let auRefus: @MainActor () -> Void

    init(
        source: SourceDeLaCloche, garde: any GardeDeLaCloche = GardeEnMemoire(),
        publier: @escaping @MainActor (ResumeCloche) -> Void = { _ in },
        auRefus: @escaping @MainActor () -> Void = {}
    ) {
        self.source = source
        self.garde = garde
        self.publier = publier
        self.auRefus = auRefus
    }

    /// En ligne, la cloche se lit et se garde ; sans réseau, la dernière gardée se montre,
    /// datée ; un jeton refusé efface tout.
    func lire() async {
        do {
            let alertes = try await source.alertes()
            garde.garder(ClocheGardee(adresse: source.adresse, alertes: alertes, aJourAu: .now))
            lecture = .lue(Cloche(alertes))
        } catch is CancellationError {
            return
        } catch is JetonRefuse {
            garde.effacer()
            auRefus()
            return
        } catch {
            if let gardee = garde.consultable(pour: source.adresse) {
                lecture = .horsLigne(Cloche(gardee.alertes), aJourAu: gardee.aJourAu)
            } else if case .lue = lecture {
                return
            } else {
                lecture = .injoignable
            }
        }
        if let resume = ResumeCloche(lecture) { publier(resume) }
    }

    /// « Réessayer » : la montre redit qu'elle charge, puis relit.
    func relire() async {
        lecture = .enCours
        await lire()
    }
}
