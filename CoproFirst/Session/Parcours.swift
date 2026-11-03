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
    }

    var chemin: [Etape] = []
    /// La résidence dont l'adresse vient d'être reconnue : sa palette colore l'écran.
    var reconnue: Installation?
    private(set) var ouverte: Installation?
    /// La feuille « Ouvrir avec Face ID ? », proposée une fois après la 1ʳᵉ connexion.
    var proposerFaceID = false
    var changerDeResidence = false
    /// Un élément du fil à ouvrir dès l'arrivée (argument `-ouvrir` des captures).
    var aOuvrir: String?
    /// L'onglet affiché dans l'espace de la résidence (identifiant de page).
    var onglet = OrdrePages.idFil
    /// Ce que l'écran de connexion doit dire en arrivant (déconnexion hors ligne…).
    var avis: String?
    let service: any ServiceCoproFirst
    let connues: InstallationsConnues

    init(service: any ServiceCoproFirst, connues: InstallationsConnues) {
        self.service = service
        self.connues = connues
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
        if premiereConnexion, !connues.faceIDProposee(installation) {
            connues.noterFaceIDProposee(installation)
            proposerFaceID = true
        }
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

    /// Quitter CETTE résidence : retour à la connexion, adresse pré-remplie.
    func deconnecter(_ installation: Installation) async {
        let atteint = await service.deconnecter(installation)
        connues.oublierFaceID(installation)
        changerDeResidence = false
        ouverte = nil
        reconnue = installation
        chemin = [.connexion(Preremplissage(installation: installation))]
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
