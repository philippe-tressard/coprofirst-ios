// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les formes que remplit `TablesAffaires` (généré par `scripts/generer.py`).

/// Une catégorie d'affaire, comme le formulaire du site la propose.
struct CategorieAffaire: Identifiable, Hashable, Sendable {
    let code: String
    let libelle: String
    let emoji: String
    let description: String
    /// Une catégorie du bâti : une affaire résolue y alimente le carnet d'entretien.
    let carnet: Bool
    /// Le serveur la refuse à qui ne modère pas (403, `categorie_reservee`).
    let reserveCS: Bool
    /// Proposée en tête (« Actualité »).
    let enTete: Bool

    var id: String { code }
}

/// Une nature d'affaire — que le serveur pose sur chacune (`natures`). `badge` est la classe
/// `badge-*` de sa teinte (`PastilleTeinte`), lue dans `normes.css` du site (#78).
struct NatureAffaire: Identifiable, Hashable, Sendable {
    let code: String
    let libelle: String
    /// Le mot abrégé de la gouttière du site (« CAL. ») : l'app écrit le libellé entier.
    let abrege: String
    let emoji: String
    let badge: String

    var id: String { code }
}

/// Une colonne du Kanban : une étape du workflow. Sa teinte est un jeton `--kanban-*`
/// de la `Palette` (claire et sombre, celle de la résidence) — `palette[keyPath: teinte]`.
struct ColonneKanban: Identifiable, Sendable {
    let id: String
    let libelle: String
    let libelleCourt: String
    let teinte: KeyPath<Palette, Color> & Sendable
}

/// Une option du filtre « Suivi » qui réunit plusieurs statuts.
struct GroupeDeSuivi: Hashable, Sendable {
    let code: String
    let libelle: String
    let statuts: [String]
}

extension TablesAffaires {
    static let categorieParCode: [String: CategorieAffaire] = Dictionary(
        uniqueKeysWithValues: categories.map { ($0.code, $0) })
    static let colonneParId: [String: ColonneKanban] = Dictionary(
        uniqueKeysWithValues: colonnesKanban.map { ($0.id, $0) })
    /// La colonne → le statut qu'elle pose : l'inverse de `colonneParStatut`, dérivé.
    static let statutParColonne: [String: String] = Dictionary(
        colonneParStatut.map { ($0.value, $0.key) }, uniquingKeysWith: { premier, _ in premier })
}
