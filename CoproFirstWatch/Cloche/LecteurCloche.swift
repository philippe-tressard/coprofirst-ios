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

    init(source: SourceDeLaCloche) {
        self.source = source
    }

    func lire() async {
        do {
            lecture = .lue(Cloche(try await source.alertes()))
        } catch is CancellationError {
            return
        } catch {
            if case .lue = lecture { return }
            lecture = .injoignable
        }
    }

    /// « Réessayer » : la montre redit qu'elle charge, puis relit.
    func relire() async {
        lecture = .enCours
        await lire()
    }
}
