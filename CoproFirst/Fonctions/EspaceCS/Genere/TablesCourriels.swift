// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.88.1 (commit e13d52923f0429fd082c92e60893e2605a3d6d27), pièce jointe tables-clients.json de la release (verdictsReleve, teinteDuTon).

/// Ce que le site écrit des Courriels affaires de l'Espace CS et que le contrat ne sert pas.
enum TablesCourriels {
    /// Ce que la relève a fait d'un message (`VERDICTS_RELEVE`), teinté par son ton.
    static let verdicts: [String: LibelleTeinte] = [
        "accepte": LibelleTeinte("Ajouté au fil", "badge-green"),
        "relance": LibelleTeinte("Transmis au conseil", "badge-blue"),
        "refuse": LibelleTeinte("Refusé", "badge-orange"),
        "ignore": LibelleTeinte("Ignoré", "badge-gray"),
        "a_classer": LibelleTeinte("À classer", "badge-orange"),
    ]
}
