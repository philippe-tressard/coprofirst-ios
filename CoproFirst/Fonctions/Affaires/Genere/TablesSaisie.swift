// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.88.1 (commit e13d52923f0429fd082c92e60893e2605a3d6d27), front/src/lib/saisie-affaire.ts (OPTIONS_SAISIE, LIBELLE_MODE) et entites/ticket.ts (TICKET) ; api/app/utils/saisie_affaire.py (MODES).

/// La saisie d'une affaire, Essentielle ou Complète : ce que le contrat ne sert pas.
enum TablesSaisie {
    /// Les choix du Profil, dans l'ordre du site : les modes que le serveur ENREGISTRE
    /// (`MODES`) — « Selon mon rôle » n'en est pas un (coprofirst#2615).
    static let options: [OptionSaisie] = [
        OptionSaisie(code: "essentielle", libelle: "Essentielle", detail: "Les champs qu’il faut, rien de plus"),
        OptionSaisie(code: "complete", libelle: "Complète", detail: "Toutes les sections, pour qualifier et suivre"),
    ]
    /// La phrase discrète du formulaire (`LIBELLE_MODE`).
    static let libellesMode: [String: String] = [
        "essentielle": "Saisie essentielle",
        "complete": "Saisie complète",
    ]
    /// Les sections d'une affaire, dans l'ordre du cadre (`TICKET`) : le vocabulaire de
    /// `sections_essentielles`.
    static let sectionsAffaire: [String] = [
        "titre",
        "nature",
        "equipement",
        "suivi",
        "quand",
        "intervenant",
        "perimetre",
        "description",
        "pieces_jointes",
        "affaires_liees",
        "au_nom_de",
        "destinataires",
        "mise_en_avant",
        "diffusion",
    ]
}
