// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Une affaire — ou une actualité, qui EST une affaire de catégorie Actualité —
/// telle que son écran de détail la montre (GET /tickets/{id} et ses évolutions).
struct DetailAffaire: Hashable, Sendable {
    let id: Int
    let numero: String
    var titre: String
    var description: String
    var categorie: String
    var statut: String
    var urgente: Bool
    let creeLe: Date
    let auteur: String?
    /// Le lieu lisible que le serveur SERT (`perimetre_libelle`) ; `nil` pour le périmètre
    /// par défaut, qu'il tait.
    var lieu: String?
    /// Ses photos et documents (`photos_urls`, `fichiers_urls`), servis derrière la session.
    var pieces: PiecesJointes = .aucune
    var suites: [SuiteAffaire]
    /// Le fil des messages (`TicketMessage`), sous l'Historique — vide sur une actualité.
    var messages: [MessageAffaire] = []
    /// Les gestes que la route accepte de CE lecteur, servis avec l'affaire.
    var droits = DroitsServisAffaire()
    var epingle = false
    var archivee = false
    /// Fusionnée dans une autre : on n'y répond plus (`gesteReponse` du site).
    var fusionnee = false
    /// Les codes de ses lieux (`perimetre_cible`) — ce que « Modifier l'affaire » part de.
    var perimetres: [String] = []
    /// L'état en clair, tel que le serveur le sert (`statut_libelle`) ; `nil` quand l'app
    /// ne le tient pas du serveur (un geste simulé) : ses référentiels le disent alors.
    var statutLibelle: String?
    /// Le suivi d'une actualité (`suivi_actualite`, un code) et son libellé servi
    /// (`suivi_actualite_libelle`, contrat 1.21.0, #127) — vide sans suivi ; `nil` d'une
    /// installation antérieure, qui ne le sert pas.
    var suiviActualite: String?
    var suiviActualiteLibelle: String?
    /// L'intervenant, tel que la fiche du site l'écrit (`intervenantAffiche`) : le
    /// prestataire, puis le rythme SERVI (`frequence_libelle`, contrat 1.20.0, #125).
    var intervenant: String?
    /// « Qui la lit », servie (`lecture`, contrat 1.22.0, #129) ; `nil` d'une installation
    /// antérieure.
    var lecture: Lecture?
    /// Les référentiels lus avec elle (`GET /tickets/referentiels`, #105) : les libellés des
    /// états de son Historique, les états qu'une Suite propose, les catégories que
    /// « Modifier » permet et les sections de sa saisie — servis, jamais recalculés ici.
    var referentiels = ReferentielsAffaires.vides
    /// Close au sens du SERVEUR (`TicketRead.close`) : sa suite est finie, sa synthèse se lit.
    var close = false
    /// Les comptes rendus où elle a été abordée (#178) ; `nil` quand la lecture a échoué —
    /// l'écran le DIT, au lieu d'une rubrique vide.
    var comptesRendus: [CompteRenduAffaire]? = []
    /// Sa synthèse, d'une affaire close seulement (#178).
    var synthese: SyntheseAffaire?

    var estActualite: Bool { categorie == "actualite" }

    /// L'état que la fiche montre (`etatAffiche` du site) : le statut d'une affaire, le
    /// suivi d'une actualité — aucun pour une actualité sans suivi. D'une installation
    /// antérieure au contrat 1.21.0 (pas de `suivi_actualite_libelle`), le statut, comme avant.
    var etat: EtatServi? {
        guard estActualite, let libelle = suiviActualiteLibelle else {
            return EtatServi(
                code: statut, libelle: StatutsAffaire.libelle(statut, servi: statutLibelle, dans: referentiels))
        }
        guard let suivi = suiviActualite, !libelle.isEmpty else { return nil }
        return EtatServi(code: suivi, libelle: libelle)
    }
}

/// Un état d'affaire : son CODE, qui choisit la teinte, et son libellé EN CLAIR, servi
/// (`StatutsAffaire.libelle(_:servi:dans:)`).
struct EtatServi: Hashable, Sendable {
    let code: String
    let libelle: String
}

/// Une entrée de l'Historique : une suite écrite, ou un changement d'état.
struct SuiteAffaire: Identifiable, Hashable, Sendable {
    let id: Int
    let type: String
    let date: Date
    let auteur: String?
    /// Les gestes que la route accepte de CE lecteur sur CETTE entrée, servis avec elle
    /// (`peut_modifier`, `peut_supprimer`, #93) — aucun quand ils ne sont pas servis.
    var droits = DroitsServisSuite()
    let contenu: String?
    let ancienStatut: String?
    let nouveauStatut: String?
    /// Ce qu'elle joint (`fichiers_urls`) : photos et documents.
    var pieces: PiecesJointes = .aucune
    /// L'état que l'entrée donne, en clair, tel que le serveur le sert
    /// (`nouveau_statut_libelle`, contrat 1.21.0, #127) ; `nil` d'une installation antérieure.
    var nouveauStatutLibelle: String?
    /// « Périmètre précisé : 🔹 Bât. 2 » — le lieu que la Suite déclare, tel que servi
    /// (`perimetre_precise_libelle`, contrat 1.24.0, #130), même par défaut ; `nil` quand
    /// elle n'en déclare pas, ou d'une installation antérieure.
    var perimetrePrecise: String?

    /// « Ouvert → Chez le syndic », pour une entrée qui change l'état. Le nouvel état se
    /// lit tel que servi avec elle ; l'ancien, que le serveur n'y met pas en clair, dans
    /// les référentiels servis avec l'affaire (`statuts[].libelle`, #105).
    func changementDEtat(_ servis: ReferentielsAffaires) -> String? {
        guard let nouveauStatut else { return nil }
        let nouveau = StatutsAffaire.libelle(nouveauStatut, servi: nouveauStatutLibelle, dans: servis)
        guard let ancienStatut else { return nouveau }
        return "\(StatutsAffaire.libelle(ancienStatut, servi: nil, dans: servis)) → \(nouveau)"
    }
}

/// Ce que la route accepte de CE lecteur, tel que le serveur le sert avec l'affaire
/// (`TicketRead.peut_*`, contrat 1.12.0) : lu, jamais recalculé ici (`standards/09` §8).
/// Un champ absent vaut « non ».
struct DroitsServisAffaire: Hashable, Sendable {
    var repondre = false
    var changerEtat = false
    /// Corriger le CONTENU — titre, description, catégorie, lieu (`peut_modifier`) :
    /// l'auteur le perd quand l'affaire est engagée, l'administration jamais.
    var modifier = false
    var archiver = false
    /// ✏️ Le crayon : ouvrir la correction (`peut_corriger`, contrat 1.21.0, #127), plus
    /// large que `modifier` — l'auteur d'une affaire engagée le garde (l'urgence, les
    /// options passent encore). D'une installation antérieure : `modifier`, comme avant.
    var corriger = false
}
