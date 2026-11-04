// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Les textes de « Mes lots & accès », écrits une fois — ceux du site
/// (`routes/(app)/mon-lot/`, `components/OngletAcces.svelte`, `LotsLocataire`,
/// `LotsBailleur`, `CaracteristiquesLot`, `OngletGestionLocative`, `InventaireBail`).
enum TextesAcces {
    // Mes lots
    static let aucunLot = "Aucun lot associé"
    static let aucunLotDetail = "Votre compte n'est pas encore lié à un lot."
    static let aucunLotAide =
        "Si votre compte vient d'être validé, la liaison se fait automatiquement. "
        + "Si aucun lot n'apparaît, contactez le gestionnaire du site ou faites une nouvelle demande."
    static let erreurLots = "Impossible d’afficher vos lots"
    static let lotAffiche = "Lot affiché"
    static let caracteristiques = "Caractéristiques"
    static let lotLoue = "🏠 Lot loué"
    static let lotsLoues = "🏠 Lots loués"
    static let lotsEnPropriete = "🏢 Lots en propriété"
    static let lotsPossedes = "🏢 Lots possédés"
    static let locataires = "👥 Locataires"
    static let lotsVacants = "🔓 Lots vacants"
    static let lotsVacantsAide =
        "Ces lots n'ont pas de bail actif. Créez un bail depuis la fiche du lot ou l'onglet Gestion locative."
    static let occupe = "Occupé"
    static let vacant = "Vacant"
    static let aucunBailActif = "Aucun bail actif"
    static let aucunBailActifAide =
        "Votre propriétaire doit vous rattacher depuis la section Gestion locative de son espace."
    static let questionsLocationSurLeSite = "Les questions sur votre location se répondent sur le site de la résidence."
    static let proprietaire = "🏢 Propriétaire :"
    static let charges = "Mes charges selon le règlement"
    /// L'app ne porte pas ce tableau : il est calculé dans le front du site
    /// (`charges-lots.ts`), et le coprofirst#2507 demande à l'API de le servir.
    static let chargesSurLeSite =
        "Le tableau de vos charges, clé par clé, se consulte sur le site de la résidence : "
        + "l'app ne recalcule pas ce que le règlement répartit."

    // Badges et télécommandes
    static let nouvelAcces = "Nouvel accès"
    static let declarerUnAcces = "Déclarer un accès"
    static let badgesVigik = "Badges d'accès (Vigik)"
    static let telecommandes = "Télécommandes de parking"
    static let aucunBadge = "Aucun badge enregistré."
    static let aucuneTelecommande = "Aucune télécommande enregistrée."
    static let signalerPerdu = "Signaler perdu"
    static let signalerPerduQuestion = "Signaler cet accès comme perdu ?"
    static let signalementEnregistre = "Signalement enregistré"
    static let accesConfies = "🏠 Accès confiés par votre bailleur"
    static let accesConfiesIntro = "Ces accès vous ont été confiés par votre propriétaire pour la durée de votre bail."
    static let aucunAccesConfie = "Aucun accès ne vous a encore été confié par votre propriétaire."
    static let vueParLocataire = "👥 Vue par locataire"
    static let vueParLocataireIntro = "Résumé des accès (Vigik / télécommandes) confiés à vos locataires."
    static let aucunBailActifPoint = "Aucun bail actif."
    static let aucunAccesConfieBadge = "Aucun accès confié"
    static let toutRecuperer = "↩ Tout récupérer"
    static let toutRecupererQuestion = "Récupérer tous les accès confiés à ce locataire ?"
    static let accesRecuperes = "Accès récupérés"
    static func accesConfiesCompte(_ n: Int) -> String { n > 1 ? "\(n) accès confiés" : "\(n) accès confié" }

    // Formulaires
    static let nouvelleDemande = "Nouvelle demande d'accès"
    static let typeDAcces = "Type d'accès"
    static let lotConcerne = "Lot concerné"
    static let selectionner = "— Sélectionner —"
    static let quantite = "Quantité"
    static let motif = "Motif"
    static let motifIndication = "Raison de la demande…"
    static let choisirUnLot = "Sélectionnez un lot"
    static let demandeEnvoyee = "Demande envoyée au conseil syndical"
    static let declarerExistant = "Déclarer un accès existant"
    static let codeReference = "Code / référence"
    static let codeIndication = "Ex : 1234567890"
    static let codeAide = "Si ce code figure dans nos imports, l'entrée sera automatiquement liée à votre compte."
    static let saisirUnCode = "Saisissez un code"
    static let accesEnregistre = "Accès enregistré"
    static let accesEnregistreImport = "Accès enregistré (import mis à jour)"
    static let annuler = "Annuler"
    static let enregistrer = "Enregistrer"
    static func lot(_ numero: String) -> String { "Lot \(numero)" }

    // Gestion locative
    static func bauxActifs(_ n: Int) -> String { "Baux actifs (\(n))" }
    static func archives(_ n: Int) -> String { "📁 Archives (\(n))" }
    static let aucunBailTermine = "Aucun bail terminé."
    static let entree = "Entrée :"
    static let sortiePrevue = "Sortie prévue :"
    static let sortieReelle = "Sortie réelle :"
    static func inventaire(_ n: Int) -> String { n == 1 ? "Inventaire (1 objet)" : "Inventaire (\(n) objets)" }
    static let aucunObjet = "Aucun objet enregistré."
    static let gestesLocationSurLeSite =
        "Créer ou terminer un bail, corriger un locataire, tenir l'inventaire : "
        + "ces gestes se font sur le site de la résidence."
}
