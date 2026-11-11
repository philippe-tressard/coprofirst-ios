// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Observation
import SwiftUI

/// Où en est l'utilisateur, d'une seule source lue par la racine :
/// la pile d'entrée (accueil, en savoir plus, connexion, démo), la résidence
/// reconnue (dont la palette s'applique aussitôt), puis la résidence ouverte.
@MainActor @Observable
final class Parcours {
    enum Etape: Hashable {
        case enSavoirPlus
        case connexion(Preremplissage)
        case demo
    }

    /// Ce que la connexion reçoit déjà rempli (démo, résidence connue).
    struct Preremplissage: Hashable {
        var installation: Installation?
        var email = ""
        var aide: String?
        /// L'utilisateur a choisi le mot de passe (ou la session n'est plus gardée) :
        /// la connexion ne redemande pas Face ID pour cette résidence.
        var parMotDePasse = false
        /// L'adresse d'une résidence jamais vue, venue d'un lien (#18) : pré-remplie,
        /// pas encore découverte.
        var adresse: URL?
        /// Venue d'un lien (#18), comme d'un QR : l'hôte se confirme toujours avant le
        /// premier mot de passe (#82).
        var depuisUnLien = false
    }

    var chemin: [Etape] = [] {
        // Revenu de la connexion où l'a mené un lien : l'utilisateur l'abandonne.
        didSet { if chemin.isEmpty, ouverte == nil { porte.enAttente = nil } }
    }
    /// La résidence dont l'adresse vient d'être reconnue : sa palette colore l'écran.
    var reconnue: Installation?
    private(set) var ouverte: Installation?
    /// La feuille « Ouvrir avec Face ID ? », proposée une fois après la 1ʳᵉ connexion.
    var proposerFaceID = false
    var changerDeResidence = false
    /// Un élément du fil à ouvrir dès l'arrivée (argument `-ouvrir` des captures, ou la
    /// porte d'une notification, `Destination.Ecran.element`).
    var aOuvrir: String?
    /// L'onglet affiché dans l'espace de la résidence (identifiant de page).
    var onglet = OrdrePages.idFil
    /// Ce que la porte d'un lien ou d'une notification retient (`Parcours+Porte`).
    var porte = EtatPorte()
    /// Ce que l'écran de connexion doit dire en arrivant (déconnexion hors ligne…).
    var avis: String?
    /// La feuille des notifications (la cloche), une seule pour tout l'espace ouvert.
    var clocheOuverte = false
    /// Les notifications push (#17) : enregistrer l'appareil à l'ouverture d'une
    /// résidence, le retirer à la déconnexion. Absentes des aperçus.
    var push: NotificationsPush?
    let service: any ServiceCoproFirst
    let connues: InstallationsConnues
    /// Le seul chemin du mot de passe : la confirmation d'un hôte jamais vu (#82).
    let garde: GardeHote

    init(service: any ServiceCoproFirst, connues: InstallationsConnues) {
        self.service = service
        self.connues = connues
        garde = GardeHote(service: service, connues: { connues.liste })
        // Au retour, la palette de la dernière résidence s'applique dès le 1er écran.
        reconnue = connues.derniere
    }

    /// La palette en vigueur : celle de la résidence ouverte ou reconnue, sinon la charte.
    var palette: Palette { (ouverte ?? reconnue)?.palette ?? .seine }

    func ouvrir(_ installation: Installation, premiereConnexion: Bool = false) {
        connues.retenir(installation)
        reconnue = installation
        ouverte = installation
        onglet = OrdrePages.idFil
        avis = nil
        chemin = []
        clocheOuverte = false
        if let push { Task { await push.residenceOuverte(installation) } }
        if premiereConnexion, !connues.faceIDProposee(installation) {
            connues.noterFaceIDProposee(installation)
            proposerFaceID = true
        }
        suivreLeLienEnAttente(installation)
    }

    /// Changer de résidence : retour à la connexion, adresse pré-remplie ou vide.
    func changer(pour installation: Installation?) {
        changerDeResidence = false
        ouverte = nil
        reconnue = installation
        chemin = [.connexion(Preremplissage(installation: installation))]
    }

    /// La résidence ouverte, telle que la liste la connaît (profil compris).
    var ouverteAJour: Installation? {
        guard let ouverte else { return nil }
        return connues.liste.first { $0.adresse == ouverte.adresse } ?? ouverte
    }

    /// Relit le profil de l'utilisateur dans la résidence ouverte (GET /auth/me).
    func rafraichirProfil() async {
        guard let installation = ouverte, let profil = try? await service.profil(installation) else { return }
        connues.noter(profil, pour: installation)
    }

    /// Quitter CETTE résidence : retour à la connexion, adresse et courriel pré-remplis —
    /// le premier écran (`EntreeView`), puisqu'elle reste la dernière ouverte.
    func deconnecter(_ installation: Installation) async {
        // L'appareil d'abord : sa route demande la session que la déconnexion va fermer.
        await push?.retirer(installation)
        let atteint = await service.deconnecter(installation)
        connues.oublierFaceID(installation)
        changerDeResidence = false
        ouverte = nil
        reconnue = installation
        chemin = []
        avis =
            atteint
            ? nil
            : "Le serveur n'a pas répondu : la session est effacée de cet appareil, il la révoquera à son expiration."
    }

    /// « Oublier toutes les résidences » : chaque session fermée, la liste vidée,
    /// retour à l'accueil — comme une app neuve.
    func oublierTout() async {
        var injoignables = 0
        for installation in connues.liste {
            await push?.retirer(installation)
            let atteint = await service.deconnecter(installation)
            injoignables += atteint ? 0 : 1
        }
        connues.vider()
        changerDeResidence = false
        ouverte = nil
        reconnue = nil
        chemin = []
        avis =
            injoignables == 0
            ? nil : "Certaines résidences n'ont pas répondu : leurs sessions sont effacées de cet appareil."
    }
}
