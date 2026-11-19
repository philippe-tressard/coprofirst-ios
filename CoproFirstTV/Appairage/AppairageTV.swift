// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Observation

/// L'appairage de l'écran de hall, sans saisie sur la télévision (#218, lot 3 ; RFC 8628) :
/// l'écran demande un code court, l'affiche, et interroge le serveur à l'intervalle imposé
/// jusqu'à ce qu'un membre du conseil le confirme (Espace CS › Écrans du hall, #295).
///
/// Un code échu ne se renouvelle PAS seul : l'écran le dit et attend « Afficher un nouveau
/// code ». Une Apple TV oubliée dans un hall n'interroge pas le serveur sans fin.
@MainActor @Observable
final class AppairageTV {
    enum Etat: Equatable {
        /// La demande part.
        case demande
        /// Le code à lire, et jusqu'à quand il vaut.
        case code(String, expireLe: Date)
        /// Le code a expiré, ou le serveur ne le connaît plus.
        case expire
        /// La demande a échoué : la phrase de l'iPhone, ou celle du serveur (429).
        case echec(ErreurService)
    }

    private(set) var etat = Etat.demande
    let residence: Installation
    private let service: any ServiceEcranTV
    private let attendre: @Sendable (Duration) async throws -> Void
    private let maintenant: @Sendable () -> Date

    init(
        residence: Installation, service: any ServiceEcranTV,
        attendre: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        maintenant: @escaping @Sendable () -> Date = { .now }
    ) {
        self.residence = residence
        self.service = service
        self.attendre = attendre
        self.maintenant = maintenant
    }

    /// Une demande, puis les interrogations jusqu'au jeton de l'écran. `nil` si le code
    /// expire, si la demande échoue ou si la tâche s'arrête (l'écran a quitté l'appairage).
    func suivre() async -> String? {
        etat = .demande
        let demande: DemandeAppairageTV
        do {
            demande = try await service.demander(residence.adresse)
        } catch {
            etat = .echec(ErreurService.depuis(error))
            return nil
        }
        let fin = maintenant().addingTimeInterval(TimeInterval(demande.expireDans))
        etat = .code(demande.codeCourt, expireLe: fin)
        var intervalle = demande.intervalle
        while true {
            do { try await attendre(.seconds(intervalle)) } catch { return nil }
            guard maintenant() < fin else {
                etat = .expire
                return nil
            }
            switch try? await service.interroger(demande.codeAppareil, residence.adresse) {
            case .jeton(let jeton, _)?:
                return jeton
            case .ralentir?:
                intervalle += ReponseAppairage.ralentissement
            case .inconnu?:
                etat = .expire
                return nil
            case .enAttente?, nil:
                // En attente du conseil, ou le réseau a manqué : on réinterroge à l'intervalle.
                continue
            }
        }
    }
}
