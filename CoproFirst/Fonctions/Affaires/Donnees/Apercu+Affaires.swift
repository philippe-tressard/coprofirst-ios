// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

extension Apercu {
    /// `close`, tel que le serveur le calcule pour un statut — lui seul le sert.
    static func close(_ statut: String) -> Bool { TablesAffaires.statutsClos.contains(statut) }

    /// Les affaires inventées : toutes les colonnes du Kanban, une actualité, des archives.
    static let affaires: [Affaire] = {
        let maintenant = Date.now
        func jours(_ n: Double) -> Date { maintenant.addingTimeInterval(-n * 86_400) }
        // swiftlint:disable:next function_parameter_count
        func affaire(
            _ id: Int, _ titre: String, _ apercu: String, _ cree: Double, _ statut: String, _ categorie: String,
            urgente: Bool = false, meConcerne: Bool? = false, archivee: Bool = false, kanban: Bool = true,
            activite: Double? = nil, prestataire: String? = nil, lieu: String? = nil, messages: Int? = nil
        ) -> Affaire {
            Affaire(
                id: id, numero: String(format: "A-%04d", id), titre: titre, apercu: apercu, creeLe: jours(cree),
                misAJourLe: activite.map(jours), statut: statut, close: close(statut),
                categorie: categorie, urgente: urgente,
                meConcerne: meConcerne, archivee: archivee, suiviKanban: kanban,
                natures: [categorie == "actualite" ? "actualite" : "activite"], prestataire: prestataire,
                perimetres: [], lieu: lieu, messages: messages)
        }
        return [
            // Du HTML, comme l'API le sert (éditeur du site) : la simulation ne doit
            // pas cacher ce que la porte `TexteDuSite` a à faire (#22).
            affaire(
                41, "Fuite d'eau au plafond du parking",
                "<p>Une infiltration goutte au niveau -1, place 12. Le sol est <strong>glissant</strong>"
                    + "&nbsp;: un seau a été posé en attendant le plombier.</p><p>Merci de contourner la zone.</p>",
                0.2, "en_cours", "panne", urgente: true, meConcerne: true, lieu: "Parking, niveau -1", messages: 6),
            affaire(
                40, "Ascenseur du bâtiment B à l'arrêt",
                "L'ascenseur reste bloqué au troisième étage depuis ce matin. Le prestataire est prévenu "
                    + "et doit passer dans la journée.",
                1, "chez_prestataire", "panne", urgente: true, prestataire: "Ascenseurs du Val",
                lieu: "Bâtiment B", messages: 3),
            affaire(
                39, "Coupure d'eau jeudi de 9 h à 12 h",
                "<p>Remplacement d'une vanne dans la cave du bâtiment A.</p>", 2, "publie", "actualite",
                meConcerne: nil, kanban: false),
            affaire(
                38, "Ravalement de la façade côté rue",
                "Le devis retenu en assemblée générale sera présenté au conseil syndical. Les échafaudages "
                    + "sont prévus au printemps, pour six semaines environ.",
                6, "en_ag", "etude_travaux", meConcerne: true, lieu: "Façade nord", messages: 12),
            affaire(
                35, "Éclairage du hall en panne",
                "Deux plafonniers ne s'allument plus dans le hall d'entrée. Les ampoules ont été changées, "
                    + "le problème vient du minuteur.",
                9, "ouvert", "panne", lieu: "Hall A", messages: 2),
            affaire(
                33, "Haie du jardin à tailler", "La haie côté rue déborde sur le trottoir.", 12, "ouvert",
                "espaces_verts", kanban: false),
            affaire(
                31, "Portail du garage remis en service",
                "La télécommande fonctionne de nouveau après le remplacement de la carte électronique.",
                21, "résolu", "panne", meConcerne: true, activite: 3, lieu: "Garage", messages: 4),
            affaire(
                27, "Nettoyage des parties communes", "Le contrat est reconduit à l'identique.", 40, "annulé",
                "nuisance", activite: 5),
            affaire(
                22, "Interphone du bâtiment A remplacé",
                "Le nouveau combiné est posé ; les noms ont été repris à l'identique.", 120, "résolu",
                "acces_accueil", archivee: true, activite: 95),
            affaire(
                18, "Infiltration en toiture", "<p>Reprise de l'étanchéité au-dessus du 5ᵉ étage.</p>", 300,
                "résolu", "sinistre", archivee: true, activite: 280, prestataire: "Toitures Dupuis"),
            affaire(
                9, "Élagage des tilleuls", "Les quatre tilleuls de la cour ont été élagués.", 520, "résolu",
                "espaces_verts", archivee: true, activite: 500),
        ]
    }()
}
