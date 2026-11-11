// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// Les arguments de lancement des tests d'interface et des captures :
/// `-api-simulee` (aucune requête ne part) et
/// `-ecran en-savoir-plus|connexion|faceid|demo|fil|affaires|retour|retour-mot-de-passe`
/// (`retour` : un habitué dont la session est gardée, `-faceid-refuse` pour un Face ID
/// annulé ; `retour-mot-de-passe` : un habitué sans Face ID), et avec `fil`,
/// `-ouvrir <type:id>` pour ouvrir d'emblée un élément du fil, `-page-renommee` pour
/// une page que l'administration a renommée, `-logement-long` pour un libellé de
/// logement qui ne tient pas dans la barre, `-compte administrateur|operateur` pour le
/// Paramétrage (#16) : administrateur et conseil, ou opérateur de la plateforme seul ;
/// `-logo-residence <contrat>` donne à la résidence un logo et sa variante sombre, et
/// le contrat qu'elle sert (`1.15.0` la demande au thème sombre, `1.14.0` non — #70) ;
/// `-lien <adresse>` : un lien universel reçu au lancement (#18) ;
/// `-push non-demandee|refusee` : l'autorisation des notifications (accordée sinon),
/// et `-push-touchee` : une notification de la résidence touchée au lancement (#17).
/// Debug seul (#84) ; hors de ces arguments, `Lancement` parle aux vraies installations.
enum LancementSimule {
    /// Sous `-api-simulee`, la vitrine est la copie embarquée, sans réseau ni cache.
    @MainActor
    static func vitrine(_ arguments: [String]) -> Vitrine? {
        arguments.contains("-api-simulee") ? Vitrine(lecteur: nil, cache: nil) : nil
    }

    @MainActor
    static func parcours(_ arguments: [String]) -> Parcours? {
        guard arguments.contains("-api-simulee") else { return nil }
        let suite = "fr.coprofirst.app.simulee"
        let reglages = UserDefaults(suiteName: suite) ?? .standard
        reglages.removePersistentDomain(forName: suite)
        let simule = ServiceSimule()
        compteSimule(arguments, simule)
        let parcours = Parcours(
            service: simule, connues: InstallationsConnues(reglages: reglages, coffre: CoffreEnMemoire()))
        simule.residenceServie = residenceSimulee(arguments)
        let residence = simule.residenceServie
        let ecran = argument("-ecran", arguments)
        switch ecran {
        case "en-savoir-plus":
            parcours.chemin = [.enSavoirPlus]
        case "connexion":
            parcours.reconnue = residence
            parcours.chemin = [.connexion(.init(installation: residence))]
        case "faceid":
            parcours.ouvrir(residence, premiereConnexion: true)
        case "demo":
            parcours.chemin = [.demo]
        case "retour", "retour-mot-de-passe":
            retourSimule(parcours, simule, residence, faceID: ecran == "retour")
        case "fil":
            var residence = residence
            if arguments.contains("-page-renommee") {
                // L'administration a renommé « Mes lots & accès » : son nom passe avant le raccourci.
                residence.surchargesPages = ["mon-lot": SurchargePage(navLabel: "Clés et badges")]
            }
            parcours.connues.noterFaceIDProposee(residence)
            parcours.ouvrir(residence)
            profilConnu(parcours, residence)
            parcours.aOuvrir = argument("-ouvrir", arguments)
        case "affaires":
            parcours.connues.noterFaceIDProposee(residence)
            parcours.ouvrir(residence)
            profilConnu(parcours, residence)
        default:
            break
        }
        suivreLeLien(arguments, parcours)
        return parcours
    }

    /// `-lien <adresse>` : un lien universel reçu au lancement (#18), par la même porte.
    @MainActor
    private static func suivreLeLien(_ arguments: [String], _ parcours: Parcours) {
        guard let lien = argument("-lien", arguments).flatMap(URL.init(string:)),
            let destination = LienUniversel.destination(lien)
        else { return }
        parcours.suivre(destination)
    }

    /// Un passage précédent : la résidence ouverte, son courriel retenu, Face ID déjà
    /// proposé — et, avec `faceID`, la session gardée au Trousseau simulé.
    @MainActor
    private static func retourSimule(
        _ parcours: Parcours, _ simule: ServiceSimule, _ residence: Installation, faceID: Bool
    ) {
        parcours.connues.retenir(residence)
        parcours.connues.noterFaceIDProposee(residence)
        parcours.connues.retenirIdentifiant("resident@exemple.fr", pour: residence)
        parcours.reconnue = residence
        if faceID { simule.garder(residence) }
    }

    /// La résidence inventée ; avec `-logo-residence <contrat>`, un logo téléversé et sa
    /// variante sombre, servis à ce contrat (#70).
    private static func residenceSimulee(_ arguments: [String]) -> Installation {
        var residence = ServiceSimule.residence
        if let contrat = argument("-logo-residence", arguments) {
            residence.aUnLogo = true
            residence.aUnLogoSombre = true
            residence.versionContrat = contrat
        }
        return residence
    }

    /// `-compte administrateur` : le compte du conseil, administrateur aussi ;
    /// `-compte operateur` : l'opérateur de la plateforme seul, compte technique (#16) ;
    /// `-compte resident` : un copropriétaire hors du conseil (le bandeau d'une affaire).
    /// `-logement-long` : un libellé qui ne tient pas dans la barre ; `-faceid-refuse` :
    /// Face ID annulé à chaque demande ; `-protection appareil|aucune` : la session gardée
    /// sans biométrie, sous le code de l'appareil ou sans rien (#84) ; `-delai-detail <ms>` :
    /// le détail d'une affaire servi en <ms>, le runner lent de la CI (#98).
    @MainActor
    private static func compteSimule(_ arguments: [String], _ simule: ServiceSimule) {
        if arguments.contains("-logement-long") {
            simule.profilSimule.libelleLogement = "Bât 4 (A), T4 duplex, 12ème étage, porte gauche"
        }
        simule.refuserFaceID = arguments.contains("-faceid-refuse")
        if let ms = argument("-delai-detail", arguments).flatMap(Int.init) {
            simule.delaiDetail = .milliseconds(ms)
        }
        switch argument("-protection", arguments) {
        case "appareil": simule.protectionSimulee = .codeAppareil
        case "aucune": simule.protectionSimulee = .aucune
        default: break
        }
        let compte = argument("-compte", arguments)
        switch compte {
        case "administrateur": simule.profilSimule.roles.append("admin")
        case "resident": simule.profilSimule.roles.removeAll { $0 == "conseil_syndical" }
        case "operateur":
            simule.profilSimule.statut = "admin_technique"
            simule.profilSimule.roles = ["operateur"]
        default: break
        }
    }

    /// Le profil d'un passage précédent, comme une résidence déjà connue le garde : la
    /// barre (`PagesOuvertes`) est complète dès l'arrivée, sans attendre GET /auth/me.
    @MainActor
    private static func profilConnu(_ parcours: Parcours, _ residence: Installation) {
        guard let simule = parcours.service as? ServiceSimule else { return }
        parcours.connues.noter(simule.profilSimule, pour: residence)
    }

    /// La valeur qui suit `nom` dans les arguments de lancement.
    static func argument(_ nom: String, _ arguments: [String]) -> String? {
        arguments.firstIndex(of: nom).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
    }
}
#endif
