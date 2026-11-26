// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.126.5 (commit 62852e89915e6bfaf695125a8cca5affa72abdcf), front/src/lib/notations.ts#ETATS, front/src/lib/notations.ts#PAR_ETAT, front/src/lib/notations.ts#SEUILS_DE_MOYENNE, front/src/lib/notations.ts#ETAT_AU_DELA (tables-clients.json), front/src/lib/notations.ts#POINTS_FORTS, front/src/lib/notations.ts#POINTS_FAIBLES, front/src/lib/notations.ts#FORME_COMMENTAIRE (tables-clients.json).

/// La notation d'un prestataire, telle que le site l'écrit.
enum TablesNotations {
    /// Les états d'un avis, dans l'ordre du site (`ETATS`).
    static let etats = ["mauvais", "neutre", "excellent"]
    /// Le libellé de chaque état (`PAR_ETAT`).
    static let libelles: [String: String] = [
        "mauvais": "Mauvais",
        "neutre": "Neutre",
        "excellent": "Excellent",
    ]
    /// La classe de teinte de chaque état (`PAR_ETAT`).
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
    /// La forme de la phrase générée et du commentaire (`FORME_COMMENTAIRE`) : le début
    /// de chaque groupe, puis ses motifs joints par `entreMotifs`, puis `finDeGroupe` ;
    /// les groupes, joints par `entreGroupes` ; le texte libre suit après `avantLibre`.
    static let phraseForts = "Points forts : "
    static let phraseFaibles = "Points faibles : "
    static let entreMotifs = ", "
    static let finDeGroupe = "."
    static let entreGroupes = " "
    static let avantLibre = "\n"
}
