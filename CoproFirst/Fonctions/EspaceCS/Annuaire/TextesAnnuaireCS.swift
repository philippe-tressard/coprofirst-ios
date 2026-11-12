// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Les mots de « Annuaire CS & Syndic », repris du site (`AnnuaireConseil.svelte`,
/// `AnnuaireSyndic.svelte`, `EnteteSyndic.svelte`, `CarteMembre.svelte`, `AideSource`).
/// Ceux qu'il partage avec l'Annuaire des résidents vivent dans `TextesAnnuaire`.
enum TextesAnnuaireCS {
    static let erreurChargement = "Erreur chargement annuaire"
    static let squelette = "AG 2026 · 12/06/2026 · Groupe WhatsApp"
    static let nouveauMembreCS = "Nouveau membre CS"
    static let nouveauMembreSyndic = "Nouveau membre Syndic"
    static let ficheMembre = "Fiche"
    static let inscritLie = "Inscrit lié"
    static let monter = "Monter"
    static let descendre = "Descendre"
    static let aucun = "Aucun"
    static let conseilEnregistre = "Conseil Syndical enregistré"
    static let syndicEnregistre = "Syndic enregistré"
    static let retirerTitre = "Retirer cette fiche de l'annuaire ?"
    static let retirerMessage = "Elle disparaît de l'annuaire des résidents dès l'enregistrement."

    /// `nom` : le nom affiché que le serveur sert avec la fiche enregistrée.
    static func enregistre(_ nom: String) -> String { "\(nom) enregistré" }

    static func gestes(_ nom: String) -> String { "Gestes pour \(nom)" }

    static func batiment(_ nom: String) -> String { "Bât. \(nom)" }

    /// « AG 2026 · 12/06/2026 », ou ce qui manque.
    static func ag(_ annee: Int?, le date: String?) -> String {
        let debut = annee.map { "AG \(String($0))" } ?? "Année AG non renseignée"
        return FormatsDuSite.lire(date).map { "\(debut) · \(FormatsDuSite.dateCourte($0))" } ?? debut
    }

    // En-tête du conseil
    static let voteEnAG = "Voté en AG"
    static let anneeIndication = "ex. 2024"
    static let dateAG = "Date de l'AG"
    static let whatsapp = "URL communauté WhatsApp"
    static let whatsappIndication = "https://chat.whatsapp.com/..."

    // En-tête du syndic
    static let nomSyndic = "Nom du syndic"
    static let nomSyndicIndication = "ex. Cabinet Bertrand"
    static let nomSyndicAbsent = "Nom du syndic non renseigné"
    static let nomDuContrat = "Vient du contrat de syndic — se change dans Prestataires → Contrats."
    static let nomSaisi = "Aucun contrat désigné : cette saisie s'affiche."
    static let adresse = "Adresse"
    static let adresseIndication = "ex. 12 rue des Lilas, 75015 Paris"
    static let siteWeb = "Espace client (site web)"

    // Fiche
    static let civilite = "Civilité"
    static let prenom = "Prénom"
    static let nom = "Nom"
    static let fonction = "Fonction"
    static let fonctionIndication = "Fonction — ex. Directeur de gérance"
    static let email = "Email"
    static let telephoneIndication = "ex. 01 23 45 67 89"
    static let ajouterTelephone = "N° de téléphone"

    static func telephones(_ n: Int) -> String { n > 1 ? "Téléphones" : "Téléphone" }
}
