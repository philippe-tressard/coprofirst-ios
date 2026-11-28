// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import EventKit
import EventKitUI
import SwiftUI

/// « Ajouter à Calendrier » (#435) : la feuille d'évènement du SYSTÈME, préremplie du
/// rendez-vous servi — la personne y choisit son calendrier, une alerte, puis « Ajouter » ;
/// « Annuler » ne laisse rien. Le seul fichier de l'app qui touche EventKit.
///
/// Aucune autorisation n'est demandée, exprès : depuis iOS 17, cette feuille s'affiche HORS
/// de l'app, qui n'écrit ni ne lit aucun calendrier — c'est iOS qui enregistre, sur le geste
/// de la personne (« Discover Calendar and EventKit », WWDC23). Aucune clé d'usage dans
/// `project.yml`, rien à la fiche de confidentialité au-delà des deux modules.
struct FeuilleAgenda: UIViewControllerRepresentable {
    let rendezVous: RendezVousAffaire
    let fermer: () -> Void

    func makeCoordinator() -> Coordinateur { Coordinateur(fermer: fermer) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let magasin = EKEventStore()
        let feuille = EKEventEditViewController()
        feuille.eventStore = magasin
        feuille.event = rendezVous.evenement(dans: magasin)
        feuille.editViewDelegate = context.coordinator
        return feuille
    }

    func updateUIViewController(_ feuille: EKEventEditViewController, context: Context) {}

    @MainActor
    final class Coordinateur: NSObject, EKEventEditViewDelegate {
        let fermer: () -> Void

        init(fermer: @escaping () -> Void) { self.fermer = fermer }

        /// Le fil du rappel n'est pas documenté (la feuille vit hors de l'app) : on y revient.
        nonisolated func eventEditViewController(
            _ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction
        ) {
            Task { @MainActor in self.fermer() }
        }
    }
}

extension RendezVousAffaire {
    /// L'évènement que la feuille propose : les champs du fichier `.ics` que le serveur sert au
    /// site sur un iPhone (`en_ics`) — notes = la description, une ligne vide, puis le lien
    /// (le lien seul, d'une affaire réservée au conseil) ; le lien aussi dans le champ URL.
    /// Même règle sur Android (coprofirst-android#412).
    func evenement(dans magasin: EKEventStore) -> EKEvent {
        let evenement = EKEvent(eventStore: magasin)
        evenement.title = titre
        evenement.startDate = debut
        evenement.endDate = fin
        evenement.location = lieu.nulSiVide
        evenement.notes = notes
        evenement.url = lien
        return evenement
    }

    /// `_description_complete` du serveur, dont le `.ics` remplit DESCRIPTION.
    var notes: String? {
        let adresse = lien?.absoluteString
        guard let texte = description.nulSiVide else { return adresse }
        return [texte, adresse].compactMap(\.self).joined(separator: "\n\n")
    }
}
