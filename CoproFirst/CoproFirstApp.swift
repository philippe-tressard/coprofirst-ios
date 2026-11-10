// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

@main
struct CoproFirstApp: App {
    @State private var parcours: Parcours
    @State private var reseau = Reseau()
    @State private var vitrine: Vitrine

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        _parcours = State(initialValue: Lancement.parcours(arguments))
        _vitrine = State(initialValue: Lancement.vitrine(arguments))
    }

    var body: some Scene {
        WindowGroup {
            RacineView()
                .environment(parcours)
                .environment(reseau)
                .environment(vitrine)
        }
    }
}

/// Les arguments de lancement des tests d'interface et des captures :
/// `-api-simulee` (aucune requête ne part) et
/// `-ecran en-savoir-plus|connexion|faceid|demo|fil|affaires`, et avec `fil`,
/// `-ouvrir <type:id>` pour ouvrir d'emblée un élément du fil, `-page-renommee` pour
/// une page que l'administration a renommée, `-logement-long` pour un libellé de
/// logement qui ne tient pas dans la barre, `-compte administrateur|operateur` pour le
/// Paramétrage (#16) : administrateur et conseil, ou opérateur de la plateforme seul.
/// Hors de ces arguments, l'app parle aux vraies installations, et lit coprofirst.fr.
enum Lancement {
    /// Sous `-api-simulee`, la vitrine est la copie embarquée, sans réseau ni cache.
    @MainActor
    static func vitrine(_ arguments: [String]) -> Vitrine {
        arguments.contains("-api-simulee") ? Vitrine(lecteur: nil, cache: nil) : .enLigne()
    }

    @MainActor
    static func parcours(_ arguments: [String]) -> Parcours {
        guard arguments.contains("-api-simulee") else {
            return Parcours(service: ServiceAPI(), connues: InstallationsConnues())
        }
        let suite = "fr.coprofirst.app.simulee"
        let reglages = UserDefaults(suiteName: suite) ?? .standard
        reglages.removePersistentDomain(forName: suite)
        let simule = ServiceSimule()
        if arguments.contains("-logement-long") {
            simule.profilSimule.libelleLogement = "Bât 4 (A), T4 duplex, 12ème étage, porte gauche"
        }
        compteSimule(arguments, simule)
        let parcours = Parcours(service: simule, connues: InstallationsConnues(reglages: reglages))
        let residence = ServiceSimule.residence
        let ecran = arguments.firstIndex(of: "-ecran").flatMap {
            arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil
        }
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
        case "fil":
            var residence = residence
            if arguments.contains("-page-renommee") {
                // L'administration a renommé « Mes lots & accès » : son nom passe avant le raccourci.
                residence.surchargesPages = ["mon-lot": SurchargePage(navLabel: "Clés et badges")]
            }
            parcours.connues.noterFaceIDProposee(residence)
            parcours.ouvrir(residence)
            profilConnu(parcours, residence)
            parcours.aOuvrir = arguments.firstIndex(of: "-ouvrir").flatMap {
                arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil
            }
        case "affaires":
            parcours.connues.noterFaceIDProposee(residence)
            parcours.ouvrir(residence)
            profilConnu(parcours, residence)
        default:
            break
        }
        return parcours
    }

    /// `-compte administrateur` : le compte du conseil, administrateur aussi ;
    /// `-compte operateur` : l'opérateur de la plateforme seul, compte technique (#16).
    @MainActor
    private static func compteSimule(_ arguments: [String], _ simule: ServiceSimule) {
        let compte = arguments.firstIndex(of: "-compte").flatMap {
            arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil
        }
        switch compte {
        case "administrateur": simule.profilSimule.roles.append("admin")
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
}
