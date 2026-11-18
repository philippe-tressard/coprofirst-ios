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
        /// D'où vient `adresse` : `.lien` (#18) se confirme toujours avant le premier
        /// mot de passe, comme un scan (`GardeHote`, #82).
        var origine: OrigineAdresse = .saisie
    }

    var chemin: [Etape] = [] {
        // Revenu de la connexion où l'a mené un lien : l'utilisateur l'abandonne.
        didSet { if chemin.isEmpty, ouverte == nil { porte.enAttente = nil } }
    }
    /// La résidence dont l'adresse vient d'être reconnue : sa palette colore l'écran.
    var reconnue: Installation?
    private(set) var ouverte: Installation? {
        // Sortir de la résidence, par quelque chemin que ce soit, sort de la consultation.
        didSet { if ouverte == nil { consultation = nil } }
    }
    /// La résidence est ouverte SANS réseau, sur sa dernière lecture gardée (#101) :
    /// on consulte, on n'agit pas (`Session/LectureGardee/Consultation.swift`).
    var consultation: ConsultationHorsLigne?
    @ObservationIgnored var repriseEnCours = false
    /// La feuille « Ouvrir avec Face ID ? », proposée une fois après la 1ʳᵉ connexion.
    var proposerFaceID = false
    var changerDeResidence = false
    /// Un élément du fil à ouvrir dès l'arrivée (argument `-ouvrir` des captures, ou la
    /// porte d'une notification, `Destination.Ecran.element`).
    var aOuvrir: String?
    /// L'onglet affiché dans l'espace de la résidence (identifiant de page).
    var onglet = OrdrePages.idFil {
        didSet { noterLeMarquePage() }
    }
    /// La charnière de l'appareil, tenue par `RacineView` (#119) : elle fait le carnet, et
    /// seule elle autorise le marque-page sur disque (`MarquePage.swift`).
    var posture = Posture.sansPli
    /// La présentation de la navigation, tenue de la classe de taille par `RacineView` :
    /// la porte d'un lien s'y règle avant même que l'espace de la résidence s'affiche (#221).
    private(set) var presentation = PresentationNavigation.barreDuBas
    /// La page ouverte dans « Plus » (barre du bas) — celle que la barre latérale reprend.
    var ouverteDansPlus: String? {
        didSet { noterLeMarquePage() }
    }
    /// Ce que la porte d'un lien ou d'une notification retient (`Parcours+Porte`).
    var porte = EtatPorte()
    /// Ce que l'écran de connexion doit dire en arrivant (déconnexion hors ligne…).
    var avis: String?
    /// La feuille des notifications (la cloche), une seule pour tout l'espace ouvert.
    var clocheOuverte = false
    /// Ce qui suit l'ouverture et la fermeture d'une résidence : les notifications push
    /// (#17), la liaison avec l'Apple Watch (#226). Aucun dans les aperçus.
    @ObservationIgnored var abonnes = AbonnesSession()
    /// La mesure d'audience (coprofirst#2726) : les écrans vus partent à la résidence
    /// ouverte, avec le canal de l'app (`Session/Audience/`).
    @ObservationIgnored let audience: MesureAudience
    let service: any ServiceCoproFirst
    let connues: InstallationsConnues
    /// Le seul chemin du mot de passe : la confirmation d'un hôte jamais vu (#82).
    let garde: GardeHote
    /// Le marque-page du pliable, par résidence (#119).
    @ObservationIgnored let marques: MarquesPages
    /// L'élément ouvert de chaque liste nommée de la résidence ouverte (`ListeEtFiche`).
    @ObservationIgnored let selections = MemoireDesSelections()

    init(service: any ServiceCoproFirst, connues: InstallationsConnues, marques: MarquesPages = .standard) {
        self.service = service
        self.connues = connues
        self.marques = marques
        garde = GardeHote(service: service, connues: { connues.liste })
        audience = MesureAudience(service: service.serviceAudience)
        // Au retour, la palette de la dernière résidence s'applique dès le 1er écran.
        reconnue = connues.derniere
        // En consultation hors ligne, rien ne se note : rien ne partirait.
        audience.courante = { [weak self] in self?.consultation == nil ? self?.ouverteAJour : nil }
        ecouterLesSessionsRefusees()
        selections.disque = disqueDesSelections
    }

    /// La palette en vigueur : celle de la résidence ouverte ou reconnue, sinon la charte.
    var palette: Palette { (ouverte ?? reconnue)?.palette ?? .seine }

    func ouvrir(
        _ installation: Installation, premiereConnexion: Bool = false, consultation: ConsultationHorsLigne? = nil
    ) {
        connues.retenir(installation)
        reconnue = installation
        ouverte = installation
        self.consultation = consultation
        // Rien des listes d'une autre résidence ; le Fil, sauf sur un pliable qui garde un
        // marque-page de celle-ci (#119).
        selections.oublier()
        let place = pageARouvrir(installation)
        onglet = place.onglet
        ouverteDansPlus = place.dansPlus
        avis = nil
        chemin = []
        clocheOuverte = false
        // Sans réseau, les abonnés seront prévenus à la reprise de la session.
        if consultation == nil { Task { [abonnes] in await abonnes.ouverte(installation) } }
        if premiereConnexion, !connues.faceIDProposee(installation) {
            connues.noterFaceIDProposee(installation)
            proposerFaceID = true
        }
        suivreLeLienEnAttente(installation)
    }

    /// Change de présentation (rotation, Split View, pliage) en gardant la page ouverte
    /// (`PresentationNavigation.traduire`).
    func presenter(_ nouvelle: PresentationNavigation) {
        guard nouvelle != presentation else { return }
        if let ouverte {
            let pages = pagesDeLaBarre(ouverte).map(\.id)
            let place = PresentationNavigation.traduire(
                .init(onglet: onglet, dansPlus: ouverteDansPlus), vers: nouvelle, pages: pages)
            onglet = place.onglet
            ouverteDansPlus = place.dansPlus
        }
        presentation = nouvelle
    }

    /// Changer de résidence : retour à la connexion, adresse pré-remplie ou vide.
    func changer(pour installation: Installation?) {
        Task { [audience] in await audience.vider() }
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
        // Une lecture partie avant la déconnexion ne redit pas le compte qu'elle a effacé (#94).
        guard ouverte?.adresse == installation.adresse else { return }
        connues.noter(profil, pour: installation)
    }

    /// Quitter CETTE résidence : retour à la connexion, adresse et courriel pré-remplis —
    /// le premier écran (`EntreeView`), puisqu'elle reste la dernière ouverte.
    func deconnecter(_ installation: Installation) async {
        // Les pages vues partent tant que la session les rattache au compte.
        await audience.vider()
        // Les abonnés d'abord : leurs retraits demandent la session que la déconnexion va fermer.
        await abonnes.fermee(installation)
        let atteint = await service.deconnecter(installation)
        let injoignable =
            "Le serveur n'a pas répondu : la session est effacée de cet appareil, il la révoquera à son expiration."
        revenirALaConnexion(installation, avis: atteint ? nil : injoignable)
    }

    /// La session de cette résidence est close (déconnexion, ou refusée par le serveur) :
    /// retour à la connexion, adresse pré-remplie, avec ce que l'écran doit dire.
    func revenirALaConnexion(_ installation: Installation, avis: String?) {
        connues.oublierFaceID(installation)
        connues.oublierLeCompte(installation)
        audience.oublier()
        changerDeResidence = false
        ouverte = nil
        reconnue = installation
        chemin = []
        self.avis = avis
    }

    /// « Oublier toutes les résidences » : chaque session fermée, la liste vidée,
    /// retour à l'accueil — comme une app neuve.
    func oublierTout() async {
        await audience.vider()
        var injoignables = 0
        for installation in connues.liste {
            await abonnes.fermee(installation)
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
