// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Une affaire telle que la liste l'affiche — lue dans `TicketRead` du contrat.
struct Affaire: Identifiable, Hashable, Sendable {
    let id: Int
    let numero: String
    let titre: String
    let apercu: String
    let creeLe: Date
    let statut: String
    let urgente: Bool
    let meConcerne: Bool
    /// Le lieu lisible (« Bâtiment A ») — absent tant que le contrat ne le sert pas.
    let lieu: String?
    /// Le nombre de messages du fil — absent tant que le contrat ne le sert pas.
    let messages: Int?

    var resolue: Bool { statut == "résolu" || statut == "annulé" }
}

/// Les filtres de la liste : une pastille chacun.
enum FiltreAffaires: String, CaseIterable, Identifiable, Sendable {
    case toutes, enCours, meConcernent, urgentes, resolues

    var id: String { rawValue }

    var libelle: String {
        switch self {
        case .toutes: "Toutes"
        case .enCours: "En cours"
        case .meConcernent: "Me concernent"
        case .urgentes: "Urgentes"
        case .resolues: "Résolues"
        }
    }

    func retient(_ affaire: Affaire) -> Bool {
        switch self {
        case .toutes: true
        case .enCours: !affaire.resolue
        case .meConcernent: affaire.meConcerne
        case .urgentes: affaire.urgente
        case .resolues: affaire.resolue
        }
    }
}

extension [Affaire] {
    /// Filtre puis recherche libre dans le titre, l'aperçu et le numéro.
    func retenues(par filtre: FiltreAffaires, recherche: String) -> [Affaire] {
        let mots = recherche.trimmingCharacters(in: .whitespaces)
        return filter { affaire in
            filtre.retient(affaire)
                && (mots.isEmpty
                    || [affaire.titre, affaire.apercu, affaire.numero].contains {
                        $0.localizedStandardContains(mots)
                    })
        }
    }
}
