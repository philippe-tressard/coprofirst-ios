// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Les mots de « Maintenance », repris du site (`OngletMaintenance.svelte`,
/// `TachesPlanifiees.svelte`, `CarteExportCopropriete.svelte`). Les noms des tâches et de
/// leurs statuts sont GÉNÉRÉS (`TablesAdmin`).
enum TextesMaintenance {
    static let introOperateur =
        "Exécution des tâches planifiées sur les nœuds de l'installation. Le nœud actif assure la maintenance "
        + "applicative (purges, VACUUM) ; le nœud en veille fait son hygiène locale et transmet son rapport au "
        + "nœud actif."
    static let introAdmin =
        "La supervision technique de l'installation — tâches planifiées, contrôles de fiabilité, base de "
        + "données — est réservée à l'opérateur de la plateforme."
    static let santeTitre = "Santé des tâches planifiées"
    static let santeErreur = "Impossible d’afficher la santé des tâches"
    static let exportTitre = "Export de la copropriété"
    static let exportErreur = "Dernier export illisible"
    static let surLeSite =
        "Lancer une tâche, l'historique de chaque exécution, les contrôles de fiabilité, le contrôle de santé, "
        + "la consommation de l'assistant IA, l'export et sa vérification, et la conservation des affaires se "
        + "font sur le site."

    static func tache(_ code: String) -> String { TablesAdmin.libellesTache[code] ?? code }

    static func dernierRapport(_ date: String) -> String { "Dernier rapport : \(date)" }

    static func enRetard(_ noeud: String) -> String { "\(noeud.uppercased()) en retard" }

    static func anomalies(_ nombre: Int, _ jours: Int) -> String {
        "\(FormatsDuSite.nombre(nombre)) exécution(s) en échec ces \(FormatsDuSite.nombre(jours)) derniers jours."
    }

    static func dernierExport(_ export: DernierExport) -> String {
        guard let archive = export.archive else { return "Aucun export dans le volume des sauvegardes." }
        let date = export.creeLe.map { ", le \(FormatsDuSite.dateHeure($0))" } ?? ""
        return "Dernier export : \(archive) — \(FormatsDuSite.octets(export.octets)), "
            + "\(FormatsDuSite.nombre(export.lignes)) lignes, \(FormatsDuSite.nombre(export.fichiers)) fichiers\(date)."
    }
}
