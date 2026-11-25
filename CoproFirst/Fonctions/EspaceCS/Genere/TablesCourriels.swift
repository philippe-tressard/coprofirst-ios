// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.126.5 (commit 62852e89915e6bfaf695125a8cca5affa72abdcf), front/src/lib/courriels-affaires.ts#VERDICTS_RELEVE, front/src/lib/journal-verdicts.ts#TEINTE_DU_TON (tables-clients.json).

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
