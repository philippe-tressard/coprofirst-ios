// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.88.1 (commit e13d52923f0429fd082c92e60893e2605a3d6d27), api/app/utils/saisie_affaire.py (SECTIONS_DE_BASE, SECTIONS_ESSENTIELLES_PAR_CATEGORIE) ; pièce jointe tables-clients.json de la release (categoriesTicket).
// swiftlint:disable line_length

#if DEBUG
/// Les catégories que l'API simulée sert (`GET /tickets/referentiels` → `categories`,
/// lues par `FixturesReferentielsAffaires`) : leurs sections essentielles CALCULÉES par
/// le générateur depuis la table du serveur. Debug seul (#84).
enum FixturesCategoriesServies {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /tickets/referentiels → `categories`, `[CategorieServie]`.
    static let categories = #"""
        [
          {"code": "panne", "libelle": "Panne", "emoji": "🛠️", "description": "Ascenseur, chauffage, éclairage, fuite, porte — à réparer", "carnet": true, "reservee": false, "permise": true, "en_tete": false, "sections_essentielles": ["titre", "nature", "perimetre", "description", "pieces_jointes", "mise_en_avant"]},
          {"code": "nuisance", "libelle": "Nuisance & propreté", "emoji": "📢", "description": "Bruit, odeurs, stationnement…", "carnet": false, "reservee": false, "permise": true, "en_tete": false, "sections_essentielles": ["titre", "nature", "perimetre", "description", "pieces_jointes"]},
          {"code": "acces_accueil", "libelle": "Accès & accueil", "emoji": "🔑", "description": "Interphone, boîte aux lettres, emménagement", "carnet": false, "reservee": false, "permise": true, "en_tete": false, "sections_essentielles": ["titre", "nature", "perimetre", "description", "pieces_jointes"]},
          {"code": "espaces_verts", "libelle": "Espaces verts", "emoji": "🌳", "description": "Élagage, haies, arrosage, allées…", "carnet": true, "reservee": false, "permise": true, "en_tete": false, "sections_essentielles": ["titre", "nature", "perimetre", "description", "pieces_jointes"]},
          {"code": "sinistre", "libelle": "Sinistre", "emoji": "💧", "description": "Dégât constaté : eau, incendie, vandalisme…", "carnet": true, "reservee": false, "permise": true, "en_tete": false, "sections_essentielles": ["titre", "nature", "perimetre", "description", "pieces_jointes", "mise_en_avant"]},
          {"code": "etude_travaux", "libelle": "Étude & travaux", "emoji": "🏗️", "description": "Diagnostic, sondage, devis, chantier suivi par le conseil", "carnet": true, "reservee": true, "permise": true, "en_tete": false, "sections_essentielles": ["titre", "nature", "perimetre", "description", "quand"]},
          {"code": "entretien", "libelle": "Entretien", "emoji": "🧰", "description": "Visite ou maintenance d’un prestataire, récurrente ou non", "carnet": true, "reservee": true, "permise": true, "en_tete": false, "sections_essentielles": ["titre", "nature", "perimetre", "description", "quand"]},
          {"code": "question", "libelle": "Question", "emoji": "❓", "description": "Information, procédure…", "carnet": false, "reservee": false, "permise": true, "en_tete": false, "sections_essentielles": ["titre", "nature", "perimetre", "description"]},
          {"code": "bug", "libelle": "Bug", "emoji": "🐛", "description": "Pb technique sur le site", "carnet": false, "reservee": false, "permise": true, "en_tete": false, "sections_essentielles": ["titre", "nature", "perimetre", "description"]},
          {"code": "actualite", "libelle": "Actualité", "emoji": "📰", "description": "Information — suivi optionnel", "carnet": false, "reservee": true, "permise": true, "en_tete": true, "sections_essentielles": ["titre", "nature", "perimetre", "description", "quand", "destinataires", "diffusion"]}
        ]
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "categories", schema: "CategorieServie", json: categories)
    ]
}
#endif
// swiftlint:enable line_length
