// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Observation
import SwiftUI

/// Les textes de l'écran, écrits une fois — ceux du site (`notifications/+page.svelte`).
enum TextesNotifications {
    static let titre = "Notifications"
    static let aujourdhui = "Aujourd'hui"
    static let anciennes = "Plus anciennes"
    static let toutMarquerLu = "Tout marquer lu"
    static let marquerLu = "Marquer lu"
    static let urgent = "Urgent"
    static let vide = "Aucune notification"
    static let videDetail = "Vous êtes à jour !"
    static let confirmerTitre = "Supprimer définitivement"
    static let confirmerMessage = "Cette notification\n\nCette action est irréversible."
    static let supprimer = "Supprimer"
    static let modifier = "Modifier"
    static let terminer = "OK"
    static let toutSelectionner = "Tout sélectionner"
    static let toutDeselectionner = "Tout désélectionner"
    static let selectionnerLues = "Sélectionner les lues"

    /// « Supprimer », puis « Supprimer (3) » dès qu'une sélection existe.
    static func supprimerSelection(_ nombre: Int) -> String {
        nombre == 0 ? supprimer : "\(supprimer) (\(nombre))"
    }

    /// Le message de la confirmation d'une suppression groupée.
    static func confirmerLot(_ nombre: Int) -> String {
        (nombre > 1 ? "Ces \(nombre) notifications" : "Cette notification") + "\n\nCette action est irréversible."
    }

    /// « 1 non lue », « 3 non lues ».
    static func nonLues(_ nombre: Int) -> String {
        nombre > 1 ? "\(nombre) non lues" : "\(nombre) non lue"
    }
}

/// Les notifications d'une résidence : chargement, liste, gestes — et le compte des
/// non lues que la cloche affiche.
@MainActor @Observable
final class EtatNotifications {
    enum Phase: Equatable {
        case chargement
        case pret
        case erreur(ErreurService)
    }

    private(set) var phase = Phase.chargement
    private(set) var liste: [NotificationRecue] = []
    /// Un geste qui a échoué : une phrase, et la liste revient à l'état d'avant.
    var echec: ErreurService?

    var nonLues: Int { liste.filter { !$0.lue }.count }

    /// Les deux sections du site : « Aujourd'hui », ce sont les 24 DERNIÈRES HEURES
    /// (`notifications/+page.svelte`, fenêtre glissante), pas le jour du calendrier.
    func sections(maintenant: Date = .now) -> (aujourdhui: [NotificationRecue], anciennes: [NotificationRecue]) {
        let seuil = maintenant.addingTimeInterval(-24 * 3600)
        return (liste.filter { $0.creeLe >= seuil }, liste.filter { $0.creeLe < seuil })
    }

    func charger(_ installation: Installation, avec service: any ServiceNotifications) async {
        if liste.isEmpty { phase = .chargement }
        do {
            let lues = try await service.notifications(installation)
            withAnimation(.snappy) {
                liste = lues
                phase = .pret
            }
        } catch {
            withAnimation(.snappy) { phase = .erreur(ErreurService.depuis(error)) }
        }
        CompteurNonLues.partage.noter(nonLues, pour: installation)
    }

    func marquerLue(
        _ notification: NotificationRecue, dans installation: Installation, avec service: any ServiceNotifications
    ) async {
        guard !notification.lue else { return }
        await tenter(installation) {
            $0 = $0.map { var n = $0; if n.id == notification.id { n.lue = true }; return n }
        } appel: {
            try await service.marquerLue(notification.id, dans: installation)
        }
    }

    func toutMarquerLu(_ installation: Installation, avec service: any ServiceNotifications) async {
        await tenter(installation) {
            $0 = $0.map { var n = $0; n.lue = true; return n }
        } appel: {
            try await service.toutMarquerLu(installation)
        }
    }

    func supprimer(
        _ notification: NotificationRecue, dans installation: Installation, avec service: any ServiceNotifications
    ) async {
        await tenter(installation) {
            $0.removeAll { $0.id == notification.id }
        } appel: {
            try await service.supprimerNotification(notification.id, dans: installation)
        }
    }

    /// Plusieurs à la fois, en UNE requête (#53) : « Supprimer les lues » quand la
    /// sélection est exactement les lues de la liste, la sélection sinon. Les lignes partent
    /// tout de suite ; si le serveur refuse, elles reviennent et sa phrase le dit. Rend
    /// `true` quand la suppression est faite.
    @discardableResult
    func supprimer(
        _ ids: Set<Int>, dans installation: Installation, avec service: any ServiceNotifications
    ) async -> Bool {
        guard !ids.isEmpty else { return false }
        let lues = Set(liste.filter(\.lue).map(\.id))
        return await tenter(installation) {
            $0.removeAll { ids.contains($0.id) }
        } appel: {
            if ids == lues {
                try await service.supprimerLues(installation)
            } else {
                try await service.supprimerNotifications(ids, dans: installation)
            }
        }
    }

    /// Le geste se voit tout de suite ; s'il échoue, la liste revient et une phrase le dit.
    @discardableResult
    private func tenter(
        _ installation: Installation, _ local: (inout [NotificationRecue]) -> Void,
        appel: () async throws -> Void
    ) async -> Bool {
        let avant = liste
        echec = nil
        withAnimation(.snappy) { local(&liste) }
        defer { CompteurNonLues.partage.noter(nonLues, pour: installation) }
        do {
            try await appel()
            return true
        } catch {
            withAnimation(.snappy) {
                liste = avant
                echec = ErreurService.depuis(error)
            }
            return false
        }
    }
}

/// Le nombre de non lues de chaque résidence, lu par la cloche de chaque onglet : une
/// seule lecture pour toutes les barres, renouvelée au plus toutes les 30 secondes.
@MainActor @Observable
final class CompteurNonLues {
    static let partage = CompteurNonLues()

    private(set) var parHote: [String: Int] = [:]
    @ObservationIgnored private var lues: [String: Date] = [:]
    @ObservationIgnored private var enCours: Set<String> = []

    func nombre(_ installation: Installation) -> Int { parHote[installation.hote] ?? 0 }

    func noter(_ nombre: Int, pour installation: Installation) {
        parHote[installation.hote] = nombre
        lues[installation.hote] = .now
    }

    /// Une lecture à la fois par résidence, détachée de la vue : la barre d'outils se
    /// redessine et annule ses tâches, la lecture va quand même au bout. Un échec ne
    /// compte pas comme lu — l'apparition suivante réessaie.
    func rafraichir(_ installation: Installation, avec service: any ServiceNotifications) async {
        let hote = installation.hote
        if enCours.contains(hote) { return }
        if let derniere = lues[hote], derniere.timeIntervalSinceNow > -30 { return }
        enCours.insert(hote)
        let lecture = Task { try? await service.notifications(installation) }
        let liste = await lecture.value
        enCours.remove(hote)
        guard let liste else { return }
        noter(liste.filter { !$0.lue }.count, pour: installation)
    }
}
