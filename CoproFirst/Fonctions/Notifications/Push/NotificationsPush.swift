// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Observation
import UserNotifications

/// Les notifications push de l'app (#17, lot P3 de la spec push de coprofirst) :
///
/// - l'autorisation se DEMANDE au bon moment — jamais au lancement, toujours après un
///   geste de l'utilisateur dans la cloche (`OffrePush`) ;
/// - l'appareil s'ENREGISTRE à chaque ouverture d'une résidence (POST /appareils, qui
///   rafraîchit `vu_le` : 60 jours sans ouverture, l'installation le purge) ;
/// - il se RETIRE à la déconnexion (DELETE /appareils/{abonnement}), avant elle ;
/// - une notification touchée OUVRE la cloche de sa résidence, retrouvée par son seul
///   abonnement : le détail se lit par l'API (GET /notifications), jamais dans la charge.
///
/// Rien de ce qui passe ici ne s'écrit dans un journal : ni le jeton, ni l'abonnement.
@MainActor @Observable
final class NotificationsPush {
    private(set) var autorisation = AutorisationPush.inconnue
    private(set) var offreReporteeLe: Date?
    @ObservationIgnored let centre: any CentreNotifications
    @ObservationIgnored let abonnements: AbonnementsPush
    @ObservationIgnored private let reglages: UserDefaults
    @ObservationIgnored private let environnement: EnvironnementAPNs
    @ObservationIgnored private weak var parcours: Parcours?
    @ObservationIgnored private var jeton: JetonAPNs?
    /// Les hôtes où le jeton courant est enregistré depuis le lancement : une fois chacun.
    @ObservationIgnored private var enregistres: Set<String> = []
    /// Une notification touchée avant que l'app soit prête (lancement à froid).
    @ObservationIgnored private var toucheeEnAttente: String?

    /// Après « Plus tard », l'offre se tait ce nombre de jours.
    static let reportJours = 14
    private static let cleReport = "push-offre-reportee"

    init(
        centre: any CentreNotifications, reglages: UserDefaults = .standard,
        environnement: EnvironnementAPNs = .courant
    ) {
        self.centre = centre
        self.reglages = reglages
        self.environnement = environnement
        abonnements = AbonnementsPush(reglages: reglages)
        if let simule = centre as? CentreSimule {
            simule.jetonRecu = { [weak self] octets in Task { await self?.jetonRecu(octets) } }
        }
    }

    /// Branche les notifications sur le parcours, une fois l'app prête.
    func attacher(_ parcours: Parcours) async {
        self.parcours = parcours
        parcours.push = self
        offreReporteeLe = reglages.object(forKey: Self.cleReport) as? Date
        await lireAutorisation()
        if let ouverte = parcours.ouverte { await residenceOuverte(ouverte) }
        if let abonnement = toucheeEnAttente {
            toucheeEnAttente = nil
            touchee(abonnement: abonnement)
        }
    }

    func lireAutorisation() async {
        autorisation = await centre.autorisation()
    }

    // MARK: - L'autorisation, au bon moment

    /// L'offre s'affiche : autorisation jamais demandée, et pas de « Plus tard » récent.
    var offreDue: Bool {
        guard autorisation == .nonDemandee else { return false }
        guard let reportee = offreReporteeLe else { return true }
        return Date.now.timeIntervalSince(reportee) > Double(Self.reportJours) * 86_400
    }

    /// « Activer » : l'alerte système, puis le jeton si elle est acceptée.
    func activer() async {
        let accordee = await centre.demander()
        await lireAutorisation()
        if accordee { centre.inscrire() }
    }

    func reporter() {
        offreReporteeLe = .now
        reglages.set(offreReporteeLe, forKey: Self.cleReport)
    }

    // MARK: - L'appareil auprès de chaque résidence

    /// iOS a donné le jeton (`DelegueApp`) : il s'enregistre auprès de la résidence ouverte.
    func jetonRecu(_ octets: Data) async {
        let neuf = JetonAPNs(octets)
        if neuf != jeton {
            jeton = neuf
            enregistres = []
        }
        if let ouverte = parcours?.ouverte { await enregistrer(ouverte) }
    }

    /// Une résidence s'ouvre, sa session en main : l'appareil s'y enregistre — si
    /// l'utilisateur a autorisé les notifications ; sinon rien ne part.
    func residenceOuverte(_ installation: Installation) async {
        await lireAutorisation()
        guard autorisation == .accordee else { return }
        await enregistrer(installation)
        // iOS redonne le jeton à chaque inscription (et le nouveau s'il a changé).
        centre.inscrire()
    }

    private func enregistrer(_ installation: Installation) async {
        guard let jeton, let service = parcours?.service.serviceAppareils,
            !enregistres.contains(installation.hote)
        else { return }
        enregistres.insert(installation.hote)
        let appareil = AppareilPush(
            jeton: jeton, environnement: environnement, abonnement: abonnements.abonnement(pour: installation))
        do {
            try await service.enregistrerAppareil(appareil, dans: installation)
        } catch {
            // La cloche reste le chemin de l'information (N9) : on réessaiera à la
            // prochaine ouverture. Rien ne se journalise.
            enregistres.remove(installation.hote)
        }
    }

    /// Avant la déconnexion : l'appareil se retire, l'abonnement s'oublie — même si le
    /// serveur ne répond pas (l'installation le purgera, et une notification qui
    /// arriverait encore ne mène plus à rien).
    func retirer(_ installation: Installation) async {
        enregistres.remove(installation.hote)
        guard let abonnement = abonnements.existant(pour: installation) else { return }
        abonnements.oublier(installation)
        try? await parcours?.service.serviceAppareils?.retirerAppareil(abonnement, dans: installation)
    }

    // MARK: - La notification reçue, touchée

    /// Une notification touchée : la cloche de SA résidence s'ouvre, par la porte commune
    /// aux liens (`Parcours.suivre`).
    /// Un abonnement inconnu (résidence quittée) n'ouvre rien.
    func touchee(abonnement: String?) {
        guard let abonnement else { return }
        guard let parcours else {
            toucheeEnAttente = abonnement
            return
        }
        guard let installation = installation(de: abonnement) else { return }
        relire(installation)
        parcours.suivre(Destination(adresse: installation.adresse, ecran: .notifications))
    }

    /// Une notification arrivée app ouverte : pour la résidence à l'écran, la cloche se
    /// relit et s'anime, sans bannière ; pour une autre, la bannière d'iOS.
    func presentation(abonnement: String?) -> UNNotificationPresentationOptions {
        guard let abonnement, let installation = installation(de: abonnement) else { return [] }
        if parcours?.ouverte?.adresse == installation.adresse {
            relire(installation)
            return [.list]
        }
        return [.banner, .list, .sound]
    }

    private func installation(de abonnement: String) -> Installation? {
        guard let hote = abonnements.hote(de: abonnement) else { return nil }
        return parcours?.connues.liste.first { $0.hote == hote }
    }

    private func relire(_ installation: Installation) {
        guard let parcours else { return }
        Task { await CompteurNonLues.partage.relire(installation, avec: parcours.serviceNotifications) }
    }
}
