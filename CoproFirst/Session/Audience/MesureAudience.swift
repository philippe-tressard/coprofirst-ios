// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import UIKit

/// **La mesure d'audience de l'app** (coprofirst#2726) : chaque écran vu se note sous le
/// chemin de l'écran ÉQUIVALENT du site (`CheminDuSite`), et part à la résidence ouverte,
/// en lot, avec le canal de l'app — le tableau de bord du site mêle alors les pages vues
/// par le site et par l'app, et dit d'où elles viennent.
///
/// Le rythme est celui du site (`front/src/lib/telemetry.ts`) : la file part toutes les
/// 30 s, dès qu'elle atteint la borne du contrat (`LimitesAudience.evenementsParLot`), et
/// au passage en arrière-plan.
///
/// Rien ne se note — défaut FERMÉ :
/// - si le compte a refusé la mesure, ou si son refus n'est pas encore connu
///   (`ProfilResidence.refusMesure`, servi par GET /auth/me) : on ne collecte pas ce que le
///   serveur jetterait ;
/// - si l'installation ne dit pas servir au moins le plancher (`version_contrat` absent,
///   illisible ou ancien) : une installation antérieure au contrat 1.31.0 ignorerait le
///   canal et compterait les vues de l'app comme celles du site. Le plancher le sert ;
///   la porte reste pourtant, comparée au plancher et non plus à 1.31.0 (#254), parce
///   qu'une version ILLISIBLE n'arrête pas la découverte (`exigerLePlancher`) : c'est
///   une porte de confidentialité, et elle reste fermée sur ce qu'on ne sait pas ;
/// - hors ligne, en consultation (#101) : rien ne partirait.
///
/// Aucun identifiant d'appareil, aucun modèle : une page, l'action `view`, le canal. Un
/// échec ne se dit pas et ne se rejoue pas — la mesure n'impacte jamais l'usage.
@MainActor
final class MesureAudience {
    /// L'action d'une page vue — celle du site (`trackPageView`).
    nonisolated static let action = "view"
    /// La file part au plus tard au bout de ce délai (`FLUSH_INTERVAL` du site).
    static let intervalleParDefaut: Duration = .seconds(30)

    /// La résidence ouverte, à jour de son profil — `nil` sans résidence ouverte, ou en
    /// consultation hors ligne. Posée par `Parcours`.
    var courante: @MainActor () -> Installation? = { nil }

    private let service: (any ServiceAudience)?
    private let intervalle: Duration
    /// Les chemins notés, pas encore partis, et la résidence à qui ils iront.
    private(set) var file: [String] = []
    private var destinataire: Installation?
    private var minuterie: Task<Void, Never>?

    init(service: (any ServiceAudience)?, intervalle: Duration = intervalleParDefaut) {
        self.service = service
        self.intervalle = intervalle
    }

    /// L'installation accepte-t-elle la mesure de CE compte, par ce canal ?
    static func mesurable(_ installation: Installation) -> Bool {
        guard let contrat = installation.contrat, contrat >= .plancher else { return false }
        return installation.profil?.refusMesure == false
    }

    /// Un écran vu : `chemin` est celui de l'écran équivalent du site.
    func noter(_ chemin: String) {
        guard let installation = courante() else { return }
        guard Self.mesurable(installation) else {
            if destinataire?.adresse == installation.adresse { oublier() }
            return
        }
        // Une page vide ou trop longue ferait refuser le lot entier : elle ne s'y met pas.
        guard !chemin.isEmpty, chemin.count <= LimitesAudience.page else { return }
        if let quittee = destinataire, quittee.adresse != installation.adresse, !file.isEmpty {
            // Ce qui reste de la résidence quittée part chez elle, pris AVANT la note neuve.
            let restantes = file
            file = []
            Task { await envoyer(restantes, a: quittee) }
        }
        destinataire = installation
        file.append(chemin)
        if file.count >= LimitesAudience.evenementsParLot {
            Task { await vider() }
        } else {
            armer()
        }
    }

    /// Envoie la file à sa résidence, par lots à la borne du contrat. Le refus posé entre
    /// la note et l'envoi est honoré : la file se jette.
    func vider() async {
        minuterie?.cancel()
        minuterie = nil
        guard let destinataire, !file.isEmpty else { return }
        let pages = file
        file = []
        if let actuelle = courante(), actuelle.adresse == destinataire.adresse, !Self.mesurable(actuelle) { return }
        await envoyer(pages, a: destinataire)
    }

    /// Les pages, par lots à la borne du contrat ; un échec ne se dit ni ne se rejoue.
    private func envoyer(_ pages: [String], a installation: Installation) async {
        for debut in stride(from: 0, to: pages.count, by: LimitesAudience.evenementsParLot) {
            let lot = Array(pages[debut..<min(debut + LimitesAudience.evenementsParLot, pages.count)])
            try? await service?.envoyer(lot, a: installation)
        }
    }

    /// Le passage en arrière-plan (le `visibilitychange` du site) : la file part, sous une
    /// tâche d'arrière-plan qu'iOS laisse finir.
    func viderEnArrierePlan() {
        guard !file.isEmpty else { return }
        let tache = TacheArrierePlan()
        tache.commencer()
        Task {
            await vider()
            tache.terminer()
        }
    }

    /// La session est close sans pouvoir rien envoyer (refusée par le serveur) : la file
    /// se jette.
    func oublier() {
        minuterie?.cancel()
        minuterie = nil
        file = []
        destinataire = nil
    }

    private func armer() {
        guard minuterie == nil else { return }
        minuterie = Task { [weak self, intervalle] in
            try? await Task.sleep(for: intervalle)
            guard !Task.isCancelled else { return }
            await self?.echeance()
        }
    }

    /// Le délai est écoulé : la minuterie se retire AVANT d'envoyer — `vider` l'annulerait,
    /// et avec elle l'envoi qu'elle porte.
    private func echeance() async {
        minuterie = nil
        await vider()
    }
}

/// Le temps qu'iOS accorde à un envoi commencé au passage en arrière-plan : terminé une
/// fois, à la fin de l'envoi ou à l'expiration du délai, au premier des deux.
@MainActor
private final class TacheArrierePlan {
    private var identifiant = UIBackgroundTaskIdentifier.invalid

    func commencer() {
        identifiant = UIApplication.shared.beginBackgroundTask(withName: "mesure-audience") { [weak self] in
            MainActor.assumeIsolated { self?.terminer() }
        }
    }

    func terminer() {
        guard identifiant != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifiant)
        identifiant = .invalid
    }
}
