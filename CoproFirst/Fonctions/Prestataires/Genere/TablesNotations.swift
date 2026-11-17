// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.103.0 (commit 1d1ed30cb3fa2128692ce2be0fe34ded87d72c69), front/src/lib/notations.ts.

/// La notation d'un prestataire, telle que le site l'écrit.
enum TablesNotations {
    /// Les états d'un avis, dans l'ordre du site (`ETATS`).
    static let etats = ["mauvais", "neutre", "excellent"]
    /// Le libellé de chaque état (`LIBELLE_ETAT`).
    static let libelles: [String: String] = [
        "mauvais": "Mauvais",
        "neutre": "Neutre",
        "excellent": "Excellent",
    ]
    /// La classe de teinte de chaque état (`TEINTE_ETAT`).
    static let teintes: [String: String] = [
        "mauvais": "badge-red",
        "neutre": "badge-gray",
        "excellent": "badge-green",
    ]
    /// L'état d'une moyenne (`etatDeMoyenne`) : sous la borne, l'état — dans l'ordre.
    static let seuilsDeMoyenne: [(borne: Double, etat: String)] = [
        (2.5, "mauvais"),
        (4, "neutre"),
    ]
    /// Au-delà de la dernière borne.
    static let etatAuDela = "excellent"
    /// Les motifs à cocher, par nature (`POINTS_FORTS`, `POINTS_FAIBLES`).
    static let pointsForts = ["délai respecté", "travail soigné", "pièces fournies", "interlocuteur réactif"]
    static let pointsFaibles = ["retard", "travail à refaire", "facture contestée", "intervenant injoignable"]
    /// Le début de chaque morceau de la phrase générée (`phraseGeneree`) : les motifs
    /// suivent, joints par « , », puis un point ; les deux morceaux, par une espace.
    static let phraseForts = "Points forts : "
    static let phraseFaibles = "Points faibles : "
}
