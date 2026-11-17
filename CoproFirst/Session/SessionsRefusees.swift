// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// LE signal d'une session que le serveur refuse EN COURS D'USAGE (#248) — l'app restée
/// ouverte au-delà du jeton de rafraîchissement (une longue inactivité), un compte
/// révoqué. La porte du renouvellement (`Renouvellement.rejouer`) le donne quand un 401
/// tient après le renouvellement ; sans lui, chaque écran disait « Votre session a
/// expiré » dans son coin et l'utilisateur restait dans un espace mort, onglet après
/// onglet. Deux écouteurs : le service efface ce que la session gardait, le parcours
/// ramène à la connexion.
///
/// La reprise (`reprendre`, `reprendreEnLigne`) ne passe pas par ici : son refus se
/// traite là où elle est appelée.
final class SessionsRefusees: @unchecked Sendable {
    private var ecouteurs: [@Sendable (String) -> Void] = []
    private let verrou = NSLock()

    /// Appelé, dans l'ordre d'inscription, avec l'hôte dont la session est refusée.
    func ecouter(_ ecouteur: @escaping @Sendable (String) -> Void) {
        verrou.withLock { ecouteurs.append(ecouteur) }
    }

    /// Le serveur refuse la session de cet hôte, renouvellement compris.
    func signaler(_ hote: String) {
        for ecouteur in verrou.withLock({ ecouteurs }) { ecouteur(hote) }
    }
}

extension Parcours {
    /// S'inscrit au signal du service : une session refusée ramène à la connexion.
    func ecouterLesSessionsRefusees() {
        service.sessionsRefusees.ecouter { [weak self] hote in
            Task { @MainActor in self?.sessionRefusee(hote) }
        }
    }

    /// La session de la résidence OUVERTE est refusée : retour à la connexion, adresse et
    /// courriel pré-remplis, et la raison dite — plutôt qu'une erreur par écran. Une autre
    /// résidence, une résidence déjà quittée (plusieurs écrans refusés à la fois) ou une
    /// consultation hors ligne (sa reprise en décide) : rien.
    func sessionRefusee(_ hote: String) {
        guard let installation = ouverte, installation.hote == hote, consultation == nil else { return }
        revenirALaConnexion(installation, avis: ErreurService.sessionExpiree.phrase)
    }
}
