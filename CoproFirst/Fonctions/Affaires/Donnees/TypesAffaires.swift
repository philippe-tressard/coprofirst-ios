// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les formes que remplit `TablesAffaires` (généré par `scripts/generer.py`).

/// Une catégorie d'affaire que la grille de saisie propose — une catégorie SERVIE que ce
/// compte peut poser (`ReferentielsAffaires.permises`, #105).
struct CategorieAffaire: Identifiable, Hashable, Sendable {
    let code: String
    let libelle: String
    let emoji: String
    let description: String
    /// Une catégorie du bâti : une affaire résolue y alimente le carnet d'entretien.
    let carnet: Bool
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
    /// Le pictogramme au trait de la gouttière du site (Lucide) : celui de la carte du fil.
    let icone: String
    let badge: String

    var id: String { code }
}

/// Une colonne du Kanban, telle que le serveur la SERT (`GET /tickets/referentiels`) :
/// une étape du workflow. Sa teinte est un jeton `--kanban-*` de la `Palette` (claire et
/// sombre, celle de la résidence), GÉNÉRÉ par code — `palette[keyPath: teinte]`.
struct ColonneKanban: Identifiable, Hashable, Sendable {
    let id: String
    let libelle: String
    let libelleCourt: String

    /// Une colonne que le site ne teinte pas encore garde un trait neutre, sans disparaître.
    var teinte: KeyPath<Palette, Color> & Sendable { TablesAffaires.teintesKanban[id] ?? \.border }
}

/// Une option du filtre « Suivi » qui réunit plusieurs statuts.
struct GroupeDeSuivi: Hashable, Sendable {
    let code: String
    let libelle: String
    let statuts: [String]
}
