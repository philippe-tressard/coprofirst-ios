// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// ⚠️ PROVISOIRE (#13) : deux tables que le site écrit DANS un composant Svelte, et
/// qu'aucun générateur ne lit proprement. coprofirst#2507 demande de les sortir dans
/// un module de `#lib` ; elles se généreront alors comme les autres (`Genere/`).
/// Recopiées à l'identique de coprofirst v3.61.0.
enum TablesDesComposants {
    /// Le type d'un objet remis au locataire — `components/InventaireBail.svelte`.
    static let typesObjet: [String: String] = [
        "cle": "🔑 Clé", "telecommande": "📡 Télécommande", "vigik": "🏷️ Vigik", "autre": "📦 Autre",
    ]

    /// Le statut d'un objet remis — `components/InventaireBail.svelte`.
    static let statutsObjet: [String: LibelleTeinte] = [
        "en_possession": LibelleTeinte("En possession", "badge-green"),
        "rendu": LibelleTeinte("Rendu", "badge-blue"),
        "perdu": LibelleTeinte("Perdu", "badge-red"),
        "non_remis": LibelleTeinte("Non remis", "badge-gray"),
    ]

    /// La gravité d'un constat sur un lot, du plus grave au moins grave —
    /// `components/ConstatsLots.svelte`.
    static let gravites: [(code: String, teinte: LibelleTeinte)] = [
        ("bloquant", LibelleTeinte("Bloquant", "badge-red")),
        ("inconnu", LibelleTeinte("Inconnu", "badge-gray")),
        ("avertissement", LibelleTeinte("À savoir", "badge-orange")),
        ("information", LibelleTeinte("Information", "badge-blue")),
    ]
}
