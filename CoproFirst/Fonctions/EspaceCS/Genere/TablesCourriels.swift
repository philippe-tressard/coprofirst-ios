// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.89.0 (commit 10b85f3356d538254bfdca6f54270063c9008d4b), front/src/lib/courriels-affaires.ts#VERDICTS_RELEVE, front/src/lib/journal-verdicts.ts#TEINTE_DU_TON (tables-clients.json).

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
