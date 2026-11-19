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
    /// Le serveur ne reconnaît plus le jeton : la liaison s'oublie, la montre attend l'iPhone.
    private let auRefus: @MainActor () -> Void

    init(source: SourceDeLaCloche, auRefus: @escaping @MainActor () -> Void = {}) {
        self.source = source
        self.auRefus = auRefus
    }

    func lire() async {
        do {
            lecture = .lue(Cloche(try await source.alertes()))
        } catch is CancellationError {
            return
        } catch is JetonRefuse {
            auRefus()
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
