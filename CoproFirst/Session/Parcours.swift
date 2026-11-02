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
}
