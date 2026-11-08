// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Les mots de « Comptes & accès », repris du site (`espace-cs/+page.svelte`,
/// `ValidationCompte.svelte`, `#lib/comptes.ts`, `#lib/commandes-acces.ts`).
enum TextesComptesCS {
    static let comptesAValider = "Compte(s) à valider"
    static let demandesDAcces = "Demande(s) d'accès"
    static let titreComptes = "Comptes en attente de validation"
    static let aucunCompte = "Aucun compte en attente."
    static let titreCommandes = "Demandes d'accès (badges / télécommandes)"
    static let aucuneCommande = "Aucune demande en attente."
    static let erreurChargement = "Erreur de chargement"

    static func aide(_ nom: String) -> String { "Aidé : \(nom)" }

    // Valider un compte
    static let nouvelArrivant = "Nouvel Arrivant"
    static let nouvelArrivantAide =
        "À cocher uniquement pour un nouveau résident qui emménage dans la copropriété. Déclenche "
        + "automatiquement : message de bienvenue, envoi des consignes de copropriété, demande d'étiquette de "
        + "boîte aux lettres auprès du syndic, et demande d'ajout sur l'interphone auprès du Conseil Syndical."
    static let nouvelArrivantMiseEnGarde =
        "Ne pas cocher pour un résident existant qui crée simplement son compte."
    static let batimentLogement = "Bâtiment / logement"
    static let batimentIndication = "Ex: Bât. A, Apt. 12…"
    static let ancienResident = "Ancien résident"
    static let ancienResidentIndication = "Nom de l'ancien occupant…"
    static let accueilEnvoye = "Actions d'accueil envoyées (bienvenue, consignes, demandes syndic/CS)."

    // Rejeter
    static func rejeterCompte(_ nom: String) -> String { "Rejeter le compte de \(nom) ?" }
    static let compteRejete = "Compte rejeté"

    // Commandes
    static let accepterCommande = "Accepter la commande"
    static let accepterMessage =
        "Les codes des badges remis seront posés sur le lot commandé. "
        + "Laissez vide si vous ne les connaissez pas encore."
    static let codesLibelle = "Codes, séparés par des virgules"
    static let codesIndication = "4521, 417D5927"
    static let accepter = "Accepter"
    static func rejeterCommande(_ nom: String) -> String { "Rejeter la demande de \(nom) ?" }
    static let commandeApprouvee = "Commande approuvée"
    static let commandeRejetee = "Commande rejetée"
}
