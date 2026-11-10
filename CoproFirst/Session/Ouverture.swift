// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que l'app doit ouvrir quand on la sollicite de l'extérieur — une notification
/// touchée (#17), un lien universel (#18). UNE seule porte pour les deux :
/// `Parcours.ouvrir(_:)`.
struct Ouverture: Hashable, Sendable {
    /// Ce qu'il faut montrer, une fois la résidence ouverte.
    enum Cible: Hashable, Sendable {
        /// La cloche : la liste des alertes, lue par GET /notifications. Une notification
        /// push ne dit rien de plus — ni quelle alerte, ni de quoi (spec push §5).
        case notifications
        /// Un élément du fil, par son identifiant `type:id` (comme `-ouvrir`).
        case element(String)
    }

    /// L'adresse de la résidence, `https://<hôte>` (`Installation.adresse`).
    let adresse: URL
    let cible: Cible
}

extension Parcours {
    /// Ouvre `demande` : aussitôt si sa résidence est ouverte ; sinon la demande attend,
    /// la résidence passe au premier plan (Face ID si sa session est gardée, la connexion
    /// pré-remplie sinon), et la cible s'ouvre à l'arrivée (`ouvrir(_:premiereConnexion:)`).
    /// Rend `false` pour une résidence que cet appareil ne connaît pas : rien ne s'ouvre —
    /// aucun annuaire, l'app ne découvre pas une installation sur une sollicitation.
    @discardableResult
    func ouvrir(_ demande: Ouverture) -> Bool {
        if let ouverte, ouverte.adresse == demande.adresse {
            enAttente = nil
            appliquer(demande.cible)
            return true
        }
        guard let installation = connues.liste.first(where: { $0.adresse == demande.adresse }) else {
            return false
        }
        enAttente = demande
        if ouverte != nil || connues.derniere?.adresse != installation.adresse || !chemin.isEmpty {
            changer(pour: installation)
        }
        // Sinon le premier écran (`EntreeView`) est déjà celui de cette résidence.
        return true
    }

    /// À l'arrivée dans une résidence : la demande qui l'attendait s'ouvre ; celle d'une
    /// autre résidence tombe — l'utilisateur a choisi d'aller ailleurs.
    func appliquerEnAttente(_ installation: Installation) {
        guard let demande = enAttente else { return }
        enAttente = nil
        if demande.adresse == installation.adresse { appliquer(demande.cible) }
    }

    private func appliquer(_ cible: Ouverture.Cible) {
        switch cible {
        case .notifications:
            clocheOuverte = true
        case .element(let id):
            clocheOuverte = false
            onglet = OrdrePages.idFil
            aOuvrir = id
        }
    }
}
