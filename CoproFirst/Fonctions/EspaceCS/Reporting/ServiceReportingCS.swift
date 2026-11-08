// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Ce que l'onglet « Reporting » de l'Espace CS demande (#15) : le Suivi des affaires,
/// CALCULÉ au serveur (`GET /suivi-affaires?mode=`) — la règle d'entrée, l'ancienneté
/// et ses seuils, les répartitions y vivent ; l'écran ne recalcule rien.
protocol ServiceReportingCS: Sendable {
    /// `affaires` (toutes les affaires non closes) ou `entretien` (les entretiens périodiques).
    func suiviAffaires(_ releve: ReleveSuivi, dans installation: Installation) async throws -> SuiviAffaires
    /// GET /reporting/renouvellements : les échéances des contrats et des diagnostics (#56).
    func renouvellements(_ installation: Installation) async throws -> Renouvellements
}

extension ContexteOngletCS {
    var serviceReporting: (any ServiceReportingCS)? { service as? any ServiceReportingCS }
}

/// Le relevé que lit un mode du suivi : le Suivi affaires et la relance lisent le même.
enum ReleveSuivi: String, Sendable {
    case affaires, entretien

    /// Le relevé d'un mode du site (`TablesReporting.modes`) — `releve` de `VueSuiviAffaires`.
    init(mode: String) { self = mode == "entretien" ? .entretien : .affaires }
}

struct SuiviAffaires: Hashable, Sendable {
    var total: Int
    /// Celles qui dépassent `delaiJours` (90 jours sur le site).
    var anciennes: Int
    var delaiJours: Int
    var fusionnees: Int
    var parCategorie: [Repartition]
    var parBatiment: [Repartition]
    /// La plus ancienne en tête, dans l'ordre servi.
    var affaires: [AffaireSuivie]
}

/// Une barre d'une répartition croisée (`BarreRead`) : son nombre, découpé en tranches.
struct Repartition: Hashable, Sendable, Identifiable {
    let cle: String
    var libelle: String
    var nombre: Int
    var tranches: [Tranche]
    var id: String { cle }

    struct Tranche: Hashable, Sendable, Identifiable {
        let cle: String
        var libelle: String
        var nombre: Int
        /// La teinte CHOISIE par le serveur (`s1`…`s8`, `p1`…`p4`, `autre`, `plusieurs`).
        var teinte: String?
        var id: String { cle }
    }
}

/// Une affaire du suivi (`AffaireOuverteRead`), dans ce que l'app en montre.
struct AffaireSuivie: Hashable, Sendable, Identifiable {
    let id: Int
    var numero: String
    var titre: String
    var statut: String
    var libelleCategorie: String
    var ouverteLe: String
    var ageJours: Int
    /// `ancienne`, `moyenne` ou `recente` — la tranche vient du serveur, qui garde les seuils.
    var anciennete: String
    /// Le résumé de l'assistant, sinon le descriptif — du TEXTE, jamais du HTML.
    var apercu: String
    var apercuIA: Bool
    var aEvolue: Bool
    var motifEvolution: String?
    /// L'état de la visite, en mode entretien (`TablesReporting.etatsVisite`).
    var etatVisite: String?

    var teinteAge: String { TablesReporting.teintesAge[anciennete] ?? "badge-gray" }
    var evolution: String {
        motifEvolution.flatMap { TablesReporting.motifsEvolution[$0] } ?? TablesReporting.motifEvolutionParDefaut
    }
}

/// La couleur d'une tranche : un jeton de la `Palette` (`--serie-*`, `--palier-*`,
/// `--color-*`), nommé par son chemin — jamais une valeur (#34). Table : `TablesReporting.tranches`.
enum CouleurDeTranche: Sendable {
    case palette(KeyPath<Palette, Color> & Sendable)

    func couleur(_ palette: Palette) -> Color {
        switch self {
        case .palette(let jeton): palette[keyPath: jeton]
        }
    }
}
