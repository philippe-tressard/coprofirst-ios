// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

extension Apercu {
    /// Les affaires inventées : toutes les colonnes du Kanban, une actualité, des archives.
    ///
    /// Telles que le SERVEUR les sert, champs calculés compris (`categorie_libelle`,
    /// `colonne_kanban`, `close`, `peut_*`) : écrits ici en données, comme une réponse —
    /// jamais déduits d'une table (#83). Le lecteur est du conseil : il glisse les cartes
    /// suivies et archive. `lApercuEstServiCommeLesReferentielsSimules` les confronte aux référentiels simulés.
    /// Les libellés d'état tels que le serveur les sert (`statut_libelle`) — des données,
    /// comme le reste de la réponse ; `lApercuEstServiCommeLesReferentielsSimules` les confronte.
    private static let statutsServis = [
        "ouvert": "Ouvert", "en_ag": "À l’AG", "en_cours": "Chez le syndic",
        "chez_prestataire": "Chez le prestataire", "résolu": "Résolu", "annulé": "Annulé", "fermé": "Fermé",
        "publie": "Publiée",
    ]

    static let affaires: [Affaire] = {
        let maintenant = Date.now
        func jours(_ n: Double) -> Date { maintenant.addingTimeInterval(-n * 86_400) }
        // swiftlint:disable:next function_parameter_count
        func affaire(
            _ id: Int, _ titre: String, _ apercu: String, _ cree: Double, _ statut: String, _ categorie: String,
            _ libelle: String, colonne: String?, close: Bool = false, urgente: Bool = false,
            meConcerne: Bool? = false, archivee: Bool = false, kanban: Bool = true, activite: Double? = nil,
            prestataire: String? = nil, lieu: String? = nil, messages: Int? = nil, lecture: String = "tous"
        ) -> Affaire {
            Affaire(
                id: id, numero: String(format: "A-%04d", id), titre: titre, apercu: apercu, creeLe: jours(cree),
                misAJourLe: activite.map(jours), statut: statut, statutLibelle: statutsServis[statut] ?? statut,
                close: close,
                categorie: categorie, categorieLibelle: libelle, urgente: urgente,
                meConcerne: meConcerne, archivee: archivee, suiviKanban: kanban,
                natures: [categorie == "actualite" ? "actualite" : "activite"], prestataire: prestataire,
                perimetres: [], lieu: lieu, messages: messages, colonne: colonne,
                peutDeplacer: kanban, peutArchiver: true, lecture: Apercu.lecture(lecture))
        }
        return [
            // Du HTML, comme l'API le sert (éditeur du site) : la simulation ne doit
            // pas cacher ce que la porte `TexteDuSite` a à faire (#22).
            affaire(
                41, "Fuite d'eau au plafond du parking",
                "<p>Une infiltration goutte au niveau -1, place 12. Le sol est <strong>glissant</strong>"
                    + "&nbsp;: un seau a été posé en attendant le plombier.</p><p>Merci de contourner la zone.</p>",
                0.2, "en_cours", "panne", "Panne", colonne: "syndic", urgente: true, meConcerne: true,
                lieu: "Parking, niveau -1", messages: 6, lecture: "reserve"),
            affaire(
                40, "Ascenseur du bâtiment B à l'arrêt",
                "L'ascenseur reste bloqué au troisième étage depuis ce matin. Le prestataire est prévenu "
                    + "et doit passer dans la journée.",
                1, "chez_prestataire", "panne", "Panne", colonne: "fournisseur", urgente: true,
                prestataire: "Ascenseurs du Val",
                lieu: "Bâtiment B", messages: 3, lecture: "reserve"),
            affaire(
                39, "Coupure d'eau jeudi de 9 h à 12 h",
                "<p>Remplacement d'une vanne dans la cave du bâtiment A.</p>", 2, "publie", "actualite", "Actualité",
                colonne: nil,
                meConcerne: nil, kanban: false),
            affaire(
                38, "Ravalement de la façade côté rue",
                "Le devis retenu en assemblée générale sera présenté au conseil syndical. Les échafaudages "
                    + "sont prévus au printemps, pour six semaines environ.",
                6, "en_ag", "etude_travaux", "Étude & travaux", colonne: "ag", meConcerne: true, lieu: "Façade nord",
                messages: 12, lecture: "copros"),
            affaire(
                35, "Éclairage du hall en panne",
                "Deux plafonniers ne s'allument plus dans le hall d'entrée. Les ampoules ont été changées, "
                    + "le problème vient du minuteur.",
                9, "ouvert", "panne", "Panne", colonne: "cs", lieu: "Hall A", messages: 2, lecture: "cs"),
            affaire(
                33, "Haie du jardin à tailler", "La haie côté rue déborde sur le trottoir.", 12, "ouvert",
                "espaces_verts", "Espaces verts", colonne: "cs", kanban: false),
            affaire(
                31, "Portail du garage remis en service",
                "La télécommande fonctionne de nouveau après le remplacement de la carte électronique.",
                21, "résolu", "panne", "Panne", colonne: "termine", close: true, meConcerne: true, activite: 3,
                lieu: "Garage", messages: 4),
            affaire(
                27, "Nettoyage des parties communes", "Le contrat est reconduit à l'identique.", 40, "annulé",
                "nuisance", "Nuisance & propreté", colonne: "annule", close: true, activite: 5, lecture: "concerne"),
            affaire(
                22, "Interphone du bâtiment A remplacé",
                "Le nouveau combiné est posé ; les noms ont été repris à l'identique.", 120, "résolu",
                "acces_accueil", "Accès & accueil", colonne: "termine", close: true, archivee: true, activite: 95),
            affaire(
                18, "Infiltration en toiture", "<p>Reprise de l'étanchéité au-dessus du 5ᵉ étage.</p>", 300,
                "résolu", "sinistre", "Sinistre", colonne: "termine", close: true, archivee: true, activite: 280,
                prestataire: "Toitures Dupuis"),
            affaire(
                9, "Élagage des tilleuls", "Les quatre tilleuls de la cour ont été élagués.", 520, "résolu",
                "espaces_verts", "Espaces verts", colonne: "termine", close: true, archivee: true, activite: 500),
        ]
    }()
}
