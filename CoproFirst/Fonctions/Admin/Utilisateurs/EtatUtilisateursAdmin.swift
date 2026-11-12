// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Observation

/// L'état de « Utilisateurs » : la liste chargée, ses filtres (recherche, type, compte)
/// et les gestes. Un geste réussi change la liste comme le serveur l'a changée.
@MainActor
@Observable
final class EtatUtilisateursAdmin {
    enum FiltreCompte: String, CaseIterable, Identifiable {
        case tous, actifs, enAttente
        var id: Self { self }
    }

    private(set) var phase = PhaseFile.chargement
    private(set) var comptes: [UtilisateurAdmin] = []
    private(set) var enCours: Int?
    var recherche = ""
    /// Un statut de compte (`TablesAdmin.ordreStatutsCompte`), ou tous.
    var statut: String?
    var compte = FiltreCompte.tous

    func charger(_ service: any ServiceUtilisateursAdmin, _ installation: Installation) async {
        do {
            comptes = try await service.utilisateurs(installation)
            phase = .pret
        } catch {
            if phase != .pret {
                phase = .erreur(ErreurService.phrase(error, sinon: TextesUtilisateursAdmin.erreur))
            }
        }
    }

    /// Les comptes retenus, triés par nom puis prénom (`comparerParNom` du site).
    var affiches: [UtilisateurAdmin] {
        comptes.filter { u in
            (statut == nil || u.statut == statut)
                && (compte == .tous || (compte == .actifs) == u.actif)
                && Recherche.contientTousLesMots([u.prenom, u.nom, u.email], recherche)
        }
        .sorted(by: Self.parNom)
    }

    /// `comparerParNom` du site : par nom, puis prénom, sans casse ni accents ; un compte
    /// sans nom en dernier.
    nonisolated static func parNom(_ a: UtilisateurAdmin, _ b: UtilisateurAdmin) -> Bool {
        let (nomA, nomB) = (a.nom.trimmingCharacters(in: .whitespaces), b.nom.trimmingCharacters(in: .whitespaces))
        if nomA.isEmpty != nomB.isEmpty { return !nomA.isEmpty }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let francais = Locale(identifier: "fr_FR")
        let parNom = nomA.compare(nomB, options: options, locale: francais)
        if parNom != .orderedSame { return parNom == .orderedAscending }
        return a.prenom.compare(b.prenom, options: options, locale: francais) == .orderedAscending
    }

    /// Les membres du conseil syndical, sur toute la liste.
    var membresDuConseil: Int { comptes.filter { $0.roles.contains("conseil_syndical") }.count }

    func compte(_ id: Int) -> UtilisateurAdmin? { comptes.first { $0.id == id } }

    /// Interdire ou réautoriser : l'état SERVI remplace l'ancien ; l'annonce le dit.
    func basculerCommunaute(
        _ utilisateur: UtilisateurAdmin, _ service: any ServiceUtilisateursAdmin, _ installation: Installation
    ) async throws -> String {
        enCours = utilisateur.id
        defer { enCours = nil }
        let interdire = !utilisateur.ban.banni()
        let ban = try await service.bannirCommunaute(utilisateur.id, interdit: interdire, dans: installation)
        if let rang = comptes.firstIndex(where: { $0.id == utilisateur.id }) { comptes[rang].ban = ban }
        let nom = utilisateur.nomAffiche
        guard interdire else { return TextesUtilisateursAdmin.reautorise(nom) }
        return ban.interdit
            ? TextesUtilisateursAdmin.banniDefinitivement(nom) : TextesUtilisateursAdmin.banniUnMois(nom)
    }

    /// Un geste de rôle servi, puis la LISTE relue : les gestes d'un compte dépendent des
    /// autres (un rôle ne se retire jamais à son dernier titulaire, `gestes_roles`).
    func changerRole(
        _ utilisateur: UtilisateurAdmin, _ offert: GesteDeRole, _ service: any ServiceUtilisateursAdmin,
        _ installation: Installation
    ) async throws -> String {
        enCours = utilisateur.id
        defer { enCours = nil }
        try await service.changerRole(utilisateur.id, role: offert.role, geste: offert.geste, dans: installation)
        await charger(service, installation)
        return TextesUtilisateursAdmin.roleChange(offert, utilisateur.nomAffiche)
    }

    func relancerRapprochement(
        _ utilisateur: UtilisateurAdmin, _ service: any ServiceUtilisateursAdmin, _ installation: Installation
    ) async throws -> PhraseAvis {
        enCours = utilisateur.id
        defer { enCours = nil }
        let annonce = try await service.relancerRapprochement(utilisateur.id, dans: installation)
        await charger(service, installation)
        return annonce
    }

    func supprimer(
        _ utilisateur: UtilisateurAdmin, _ service: any ServiceUtilisateursAdmin, _ installation: Installation
    ) async throws -> String {
        enCours = utilisateur.id
        defer { enCours = nil }
        try await service.supprimerUtilisateur(utilisateur.id, dans: installation)
        comptes.removeAll { $0.id == utilisateur.id }
        return TextesUtilisateursAdmin.supprime(utilisateur.nomAffiche)
    }
}

/// Les mots de « Utilisateurs », repris du site (`OngletUtilisateurs.svelte`,
/// `FiltresUtilisateurs.svelte`, `#lib/comptes.ts`).
enum TextesUtilisateursAdmin {
    static let erreur = "Impossible d’afficher les utilisateurs"
    static let recherche = "Rechercher un nom, un e-mail…"
    static let aucunResultat = "Aucun résultat"
    static let type = "Type"
    static let tousTypes = "Tous types"
    static let tousComptes = "Tous comptes"
    static let actifs = "Actifs"
    static let enAttente = "En attente"
    static let actif = "Actif"
    static let emailNonVerifie = "Email non vérifié"
    static func compteur(_ affiches: Int, _ total: Int, _ conseil: Int) -> String {
        let base =
            affiches == total
            ? "\(FormatsDuSite.nombre(total)) comptes"
            : "\(FormatsDuSite.nombre(affiches)) sur \(FormatsDuSite.nombre(total))"
        return "\(base) · \(FormatsDuSite.nombre(conseil)) au conseil syndical"
    }
    static func bailleur(_ nom: String) -> String { "Bailleur : \(nom)" }
    static func purgeAvertie(_ date: String) -> String { "Inactif, averti le \(date)" }
    static let purgeAide = "Supprimé trente jours après cet avertissement s'il ne se reconnecte pas."

    // La fiche
    static let fermer = "Fermer"
    static let identite = "Compte"
    static let email = "E-mail"
    static let statut = "Type"
    static let batiment = "Bâtiment"
    static let inscription = "Inscription"
    static let derniereConnexion = "Dernière connexion"
    static let roles = "Rôles actifs"
    static let etiquettes = "Rattachements"
    static let communaute = "Communauté"
    static let autorisee = "Autorisée"
    static let banniPourDeBon = "Banni définitivement"
    static func banniJusquAu(_ date: String) -> String { "Banni jusqu'au \(date) (probatoire)" }
    static let interdire = "Interdire la communauté"
    static let autoriser = "Autoriser la communauté"
    static let rapprochement = "Rejouer l'auto-match des lots"
    static let supprimer = "Supprimer le compte"
    static func confirmerSuppression(_ nom: String, _ email: String) -> String {
        "Le compte de \(nom) (\(email)) sera supprimé définitivement."
    }
    static let surLeSite =
        "Modifier la fiche, ajouter ou retirer un rôle et l'accueil d'un arrivant se font sur le site."
    /// Quand l'installation sert les gestes de rôle (contrat 1.18.0) : ils sont ici.
    static let surLeSiteSansRoles = "Modifier la fiche et l'accueil d'un arrivant se font sur le site."

    // Les gestes de rôle (`GestesRolesCompte.svelte`, `OngletUtilisateurs.svelte`)
    static let gestesRoles = "Rôles"
    /// Le nom d'un rôle sur son bouton : « CS » pour le conseil syndical, comme le site,
    /// son libellé (`RolesUtilisateur`, généré) pour les autres.
    static func roleCourt(_ role: String) -> String {
        role == "conseil_syndical" ? "CS" : RolesUtilisateur.libelleRole(role)
    }
    /// « + CS », « – Admin » : le tiret demi-cadratin du site.
    static func bouton(_ offert: GesteDeRole) -> String {
        (offert.geste == .ajouter ? "+ " : "– ") + roleCourt(offert.role)
    }
    /// « Ajouter le rôle Admin » — ce que VoiceOver lit du bouton, et le début de sa question.
    static func actionRole(_ offert: GesteDeRole) -> String {
        "\(offert.geste == .ajouter ? "Ajouter" : "Retirer") le rôle \(RolesUtilisateur.libelleRole(offert.role))"
    }
    static func confirmerRole(_ offert: GesteDeRole, _ nom: String) -> String {
        "\(actionRole(offert)) \(offert.geste == .ajouter ? "à" : "de") \(nom) ?"
    }
    static let notifie = "Cette personne recevra une notification."
    static let confirmer = "Confirmer"

    // Les annonces
    static func banniDefinitivement(_ nom: String) -> String { "\(nom) banni définitivement de la communauté." }
    static func banniUnMois(_ nom: String) -> String { "\(nom) banni de la communauté pour 1 mois (probatoire)." }
    static func reautorise(_ nom: String) -> String { "\(nom) réautorisé à la communauté." }
    static func supprime(_ nom: String) -> String { "\(nom) supprimé." }
    static func roleChange(_ offert: GesteDeRole, _ nom: String) -> String {
        let role = RolesUtilisateur.libelleRole(offert.role)
        return offert.geste == .ajouter ? "Rôle \(role) ajouté à \(nom)." : "Rôle \(role) retiré de \(nom)."
    }

    /// Les rattachements d'un compte (`ETIQUETTES_COMPTE`), dans l'ordre du site.
    static let etiquettesCompte: [EtiquetteCompte] = [
        EtiquetteCompte(cle: "loti", libelle: "Loti", ok: "Rattaché à au moins un lot", manque: "Aucun lot rattaché"),
        EtiquetteCompte(
            cle: "tc", libelle: "TC", ok: "Porte une télécommande", manque: "Un parking, mais aucune télécommande",
            sansObjet: "Sans objet : aucun parking"),
        EtiquetteCompte(
            cle: "vigik", libelle: "Vigik", ok: "Porte un badge Vigik", manque: "Un appartement, mais aucun Vigik",
            sansObjet: "Sans objet : aucun appartement"),
        EtiquetteCompte(
            cle: "bail", libelle: "Bail", ok: "Un bail enregistré",
            manque: "Bailleur ou locataire, mais aucun bail enregistré",
            sansObjet: "Sans objet : ni bailleur, ni locataire"),
    ]
}

/// Un rattachement d'un compte (`ETIQUETTES_COMPTE`) : son libellé, et ce que dit chacun
/// des trois états que le serveur sert (`ok`, `manque`, `sans_objet`).
struct EtiquetteCompte {
    let cle: String
    let libelle: String
    let ok: String
    let manque: String
    var sansObjet = ""

    func texte(_ etat: String) -> String {
        switch etat {
        case "ok": ok
        case "manque": manque
        default: sansObjet
        }
    }
}
