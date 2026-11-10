// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Les mots de « Télémétrie », repris du site (`OngletTelemetrie.svelte`,
/// `FrequentationTelemetrie.svelte`, `TopPages.svelte`).
enum TextesTelemetrie {
    static let chargement = "Chargement des statistiques…"
    static let erreur = "Impossible d’afficher les statistiques"
    static let vide = "Aucune donnée de télémétrie"
    static let videMessage = "Les données apparaîtront après les premières visites."
    static let sansGestionnaire = "Sans le gestionnaire du site"
    static let aucunGestionnaire =
        "Aucun gestionnaire du site n’est désigné (Copropriété › Fonctionnement) : le filtre « sans le "
        + "gestionnaire du site » n’a donc rien à écarter."
    static func filtreApplique(jusquAu: String?) -> String {
        let base =
            "Les vues du gestionnaire du site sont écartées des indicateurs, du graphe, des pages, des "
            + "utilisateurs, de « Qui vient » et des arrivées par notification. Les erreurs, les gestes et "
            + "les durées d’affichage, sans compte, ne changent pas."
        guard let jusquAu else { return base }
        return base + " Jusqu’au \(FormatsDuSite.date(jusquAu)), les agrégats ne distinguaient pas le "
            + "gestionnaire : ses vues y restent comptées."
    }
    static let pagesVues = "Pages les plus vues"
    static let utilisateursActifs = "Utilisateurs actifs"
    static let periode = "Période"
    static let vuesAxe = "Vues"
    static let surLeSite =
        "Les erreurs vues par les résidents, « Qui vient », le retour des comptes, les gestes aboutis, les "
        + "arrivées par notification et les durées d’affichage se consultent sur le site."

    static func vue(_ portee: PorteeTelemetrie) -> String {
        switch portee {
        case .jour: "Jour"
        case .mois: "Mois (30 j)"
        case .annee: "Année (12 mois)"
        case .total: "Total (10 ans)"
        }
    }

    static func vuesEtUniques(_ total: Int, _ uniques: Int) -> String {
        "\(FormatsDuSite.nombre(total)) vues · \(FormatsDuSite.nombre(uniques)) uniques"
    }

    static func vuesEtPages(_ total: Int, _ pages: Int) -> String {
        "\(FormatsDuSite.nombre(total)) vues · \(FormatsDuSite.nombre(pages)) pages"
    }

    static func derniereConnexion(_ date: String) -> String { "Dernière connexion : \(date)" }

    /// L'étiquette d'un bâton sous le graphe : l'heure servie (« 18h »), le numéro du
    /// jour (« MM-JJ » → « 4 »), le mois court (« AAAA-MM » → « nov. »), l'année.
    static func etiquette(_ label: String, _ portee: PorteeTelemetrie) -> String {
        let morceaux = label.split(separator: "-").compactMap { Int($0) }
        switch portee {
        case .mois where morceaux.count == 2: return String(morceaux[1])
        case .annee where morceaux.count == 2: return FormatsDuSite.moisCourt(morceaux[1])
        default: return label
        }
    }

    /// Le même bâton, en entier, pour VoiceOver : « 4 nov. », « novembre 2026 ».
    static func libelle(_ label: String, _ portee: PorteeTelemetrie) -> String {
        let morceaux = label.split(separator: "-").compactMap { Int($0) }
        switch portee {
        case .mois where morceaux.count == 2: return "\(morceaux[1]) \(FormatsDuSite.moisCourt(morceaux[0]))"
        case .annee: return FormatsDuSite.moisAnnee(label)
        default: return label
        }
    }

    static func valeur(_ baton: TableauTelemetrie.Baton) -> String {
        let vues = "\(FormatsDuSite.nombre(baton.total)) vues"
        return baton.uniques.map { "\(vues), \(FormatsDuSite.nombre($0)) uniques" } ?? vues
    }

    /// Les nombres clés que la vue sert, dans l'ordre du site, chacun avec son libellé.
    static func indicateurs(
        _ kpi: TableauTelemetrie.Indicateurs, _ portee: PorteeTelemetrie
    ) -> [(valeur: String, libelle: String)] {
        var liste: [(String, String)] = [(FormatsDuSite.nombre(kpi.vues ?? 0), vuesDe(portee))]
        if let utilisateurs = kpi.utilisateurs {
            liste.append(
                (
                    FormatsDuSite.nombre(utilisateurs),
                    portee == .jour ? "Utilisateurs actifs aujourd'hui" : "Utilisateurs uniques (pic)"
                ))
        }
        liste.append((FormatsDuSite.nombre(kpi.pages ?? 0), "Pages distinctes visitées"))
        if let heure = kpi.heurePointe { liste.append((heure, "Heure de pointe")) }
        let moyennes: [(Double?, String)] = [
            (kpi.moyVuesUtilisateur, "Moy. vues / utilisateur"), (kpi.moyVuesJour, "Moy. vues / jour"),
            (kpi.moyUtilisateursJour, "Moy. utilisateurs / jour"),
            (kpi.moisActifs.map(Double.init), "Mois avec activité"), (kpi.moyVuesMois, "Moy. vues / mois"),
            (kpi.anneesActives.map(Double.init), "Années avec activité"), (kpi.moyVuesAn, "Moy. vues / an"),
        ]
        liste += moyennes.compactMap { valeur, libelle in valeur.map { (FormatsDuSite.nombre($0), libelle) } }
        if let record = kpi.recordJour {
            liste.append((utilisateurs(record.uniques), "Record jour — \(FormatsDuSite.date(record.jour))"))
        }
        if let record = kpi.recordMois {
            liste.append((utilisateurs(record.uniques), "Record mois — \(FormatsDuSite.moisAnnee(record.mois))"))
        }
        return liste.map { (valeur: $0.0, libelle: $0.1) }
    }

    private static func utilisateurs(_ nombre: Int) -> String { "\(FormatsDuSite.nombre(nombre)) utilisateurs" }

    private static func vuesDe(_ portee: PorteeTelemetrie) -> String {
        switch portee {
        case .jour: "Pages vues aujourd'hui"
        case .mois: "Pages vues (30 j)"
        case .annee: "Pages vues (12 mois)"
        case .total: "Pages vues (total)"
        }
    }
}
