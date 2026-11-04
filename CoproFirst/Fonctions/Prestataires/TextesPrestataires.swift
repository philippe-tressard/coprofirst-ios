// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Les textes de « Prestataires », écrits une fois — ceux du site
/// (`OngletPrestataires`, `CartePrestataire`, `NotationsPrestataire`,
/// `OngletContrats`, `CarteContrat`, `OngletConsommations`).
enum TextesPrestataires {
    // Prestataires
    static let recherche = "Nom, métier, équipement, contact, téléphone…"
    static let categorie = "Catégorie"
    static let contrat = "Contrat"
    static let tous = "Tous"
    static let aucunPrestataire = "Aucun prestataire"
    static let aucunPrestatairePourCriteres = "Aucun prestataire pour ces critères"
    static func aucunActif(_ filtre: Bool) -> String { "Aucun prestataire actif\(filtre ? " pour ces critères" : "")" }
    static let archivesRangees = "Les fiches archivées sont rangées dans les Archives, ci-dessous."
    static let archives = "📁 Archives"
    static func sousContrat(_ n: Int) -> String { "📄 Sous contrat (\(n))" }
    static let telephone = "Téléphone"
    static let email = "Email"
    static let adresse = "Adresse"
    static let contrats = "Contrats"
    static let prochaineVisite = "Prochaine visite"
    static func avisDuConseil(_ n: Int) -> String { "Avis du conseil syndical (\(n))" }

    // Contrats
    static func contratsActifs(_ n: Int) -> String { n > 1 ? "\(n) contrats actifs" : "\(n) contrat actif" }
    static func sansEcheance(_ n: Int) -> String { "\(n) sans échéance" }
    static let aucunContrat = "Aucun contrat"
    static let aucunContratActif = "Aucun contrat actif"
    static let contratsArchivesRanges = "Les contrats archivés sont rangés dans les Archives, ci-dessous."
    static let sansIntervenant = "sans intervenant"
    static let sansEcheanceCapsule = "Sans échéance"
    static let leContrat = "Le contrat"
    static let debut = "Début"
    static let dureeInitiale = "Durée initiale"
    static let description = "Description"
    static func documents(_ n: Int) -> String { "Documents (\(n))" }
    static let aucunDocument = "Aucun document."

    // Consommations
    static let compteur = "Compteur"
    static let aucunReleve = "Aucun relevé"
    static func index(_ valeur: String) -> String { "Index \(valeur)" }
    static let releveSansIndex = "Relevé sans index"
    static let photoDuReleve = "Relevé de compteur"
    static let aucunFournisseur = "Aucun fournisseur"

    /// Les gestes du conseil syndical, que l'app ne porte pas encore (coprofirst#2507).
    static let gestesSurLeSite =
        "Ajouter ou corriger une fiche, un contrat ou un relevé, noter un prestataire, archiver : "
        + "ces gestes du conseil syndical se font sur le site de la résidence."
}
