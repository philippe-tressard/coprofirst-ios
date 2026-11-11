// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Le contenu inventé que l'interface montre HORS de toute simulation : l'illustration
/// d'« En savoir plus » et la forme des squelettes pendant un chargement. Compilé dans
/// tous les builds — rien n'y vient d'une personne ni d'une adresse réelle. Le service
/// simulé (`ServiceSimule`, Debug seul, #84) le sert aussi : une seule source.
enum Apercu {
    /// Le fil inventé : trois jours, toutes les natures, une urgence.
    static let fil: [ElementDuFil] = {
        let calendrier = Chronologie.calendrier
        let aujourdhui = calendrier.startOfDay(for: .now)
        func le(_ jours: Int, _ heure: Int) -> Date {
            let jour = calendrier.date(byAdding: .day, value: -jours, to: aujourdhui) ?? aujourdhui
            return calendrier.date(byAdding: .hour, value: heure, to: jour) ?? jour
        }
        // Le constructeur des éléments inventés : un paramètre par champ du fil.
        // swiftlint:disable:next function_parameter_count
        func element(
            _ id: String, _ type: String, _ date: Date, _ titre: String, _ detail: String?,
            badges: [String] = [], meConcerne: Bool = false, cible: CibleDuFil, meta: String? = nil
        ) -> ElementDuFil {
            ElementDuFil(
                id: "\(type):\(id)", type: type, date: date, titre: titre, detail: detail, badges: badges,
                publicationUrgente: false, statut: nil, meConcerne: meConcerne, cible: cible,
                echeance: meta.flatMap(EcheanceDuFil.init(metaJSON:)),
                natures: meta.flatMap(MetaDuFil.init(json:))?.affaire?.natures ?? [],
                pieces: meta.flatMap(MetaDuFil.init(json:))?.pieces ?? .aucune)
        }
        return [
            element(
                "41", "ticket_ouvert", le(0, 9), "Fuite d'eau au plafond du parking",
                "<p>Niveau -1, place 12. Le plombier passe dans la <em>matinée</em>.</p>", badges: ["urgent"],
                meConcerne: true,
                cible: .affaire(id: 41), meta: piecesDe41),
            element(
                "12", "publication", le(0, 8), "Coupure d'eau jeudi de 9 h à 12 h",
                "Remplacement d'une vanne dans la cave du bâtiment A.", cible: .affaire(id: 12),
                meta: metaAffaire(
                    dans: 2, etat: "a_venir", libelle: "J-2", natures: ["actualite", "calendrier"])),
            element(
                "44", "ticket_mis_a_jour", le(0, 7), "Ramonage des conduits de cheminée",
                "Le ramoneur passe dans les caves du bâtiment B.", cible: .affaire(id: 44),
                meta: metaAffaire(dans: 0, etat: "jour_j", libelle: "Jour J")),
            element(
                "3", "sondage_ouvert", le(1, 18), "Quel jour pour la fête des voisins ?",
                "Trois dates proposées, réponses jusqu'à vendredi.", cible: .sondage(id: 3)),
            element(
                "7", "document", le(1, 11), "Procès-verbal de l'assemblée générale",
                "Ajouté dans Documents › Assemblées.", cible: .document(id: 7, nom: "proces-verbal-ag.pdf")),
            element(
                "2", "point_conseil", le(2, 17), "Point avec le syndic",
                "Ordre du jour : ascenseur, ravalement, contrat d'entretien.", cible: .resume(lien: nil),
                meta: #"{"fichiers_urls": ["/uploads/evenements/ordre-du-jour.pdf"]}"#),
            element(
                "38", "ticket_mis_a_jour", le(2, 10), "Ravalement de la façade côté rue",
                "Le devis retenu sera présenté au conseil syndical.", meConcerne: true, cible: .affaire(id: 38),
                meta: metaAffaire(dans: 8, jusquA: 10, etat: "a_venir", libelle: "J-8")),
            element(
                "45", "ticket_mis_a_jour", le(3, 16), "Contrôle annuel de l'ascenseur",
                "Le rapport du contrôleur est attendu.", cible: .affaire(id: 45),
                meta: metaAffaire(dans: -3, etat: "passee", libelle: "Passé")),
            element(
                "31", "ticket_resolu", le(4, 15), "Portail du garage remis en service",
                "La carte électronique a été remplacée.", cible: .affaire(id: 31),
                meta: metaAffaire(dans: -4, etat: "close", libelle: nil)),
        ]
    }()

    /// `meta` de l'affaire 41 : sa nature, ses quatre photos et son devis (`meta.photos_urls`,
    /// `meta.fichiers_urls`), comme le serveur les sert.
    private static let piecesDe41 =
        #"{"affaire": {"natures": ["activite"]}, "photos_urls": ["/uploads/tickets/41-1.jpg", "#
        + #""/uploads/tickets/41-2.jpg", "/uploads/tickets/41-3.jpg", "/uploads/tickets/41-4.jpg"], "#
        + #""fichiers_urls": ["/uploads/tickets/0123456789abcdef0123456789abcdef_Devis%20plombier.pdf"]}"#

    /// `meta` d'une affaire datée, à la forme que sert coprofirst v3.79.0 (`meta.affaire`,
    /// `flux/commun.pastilles_affaire`) : début à 9 h, à `dans` jours d'aujourd'hui, et
    /// fin le jour `jusquA`. Le délai est celui du serveur simulé, écrit comme lui ; les natures,
    /// celles que `utils/nature_affaire` dérive (une actualité datée en porte deux).
    private static func metaAffaire(
        dans: Int, jusquA: Int? = nil, etat: String, libelle: String?, natures: [String] = ["calendrier"]
    ) -> String {
        let calendrier = Chronologie.calendrier
        func iso(_ jours: Int, heure: Int) -> String {
            let jour = calendrier.date(byAdding: .day, value: jours, to: calendrier.startOfDay(for: .now)) ?? .now
            let instant = calendrier.date(byAdding: .hour, value: heure, to: jour) ?? jour
            // UTC naïf, comme le serveur sérialise ses colonnes de date.
            return instant.formatted(
                Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day().dateTimeSeparator(.standard)
                    .time(includingFractionalSeconds: false))
        }
        let fin = jusquA.map { "\"\(iso($0, heure: 17))\"" } ?? "null"
        let delai = libelle.map { "\"\($0)\"" } ?? "null"
        return #"""
            {"affaire": {"debut": "\#(iso(dans, heure: 9))",
             "fin": \#(fin), "echeance": {"etat": "\#(etat)", "jours": \#(dans), "libelle": \#(delai),
             "plusieurs_jours": \#(jusquA != nil)},
             "natures": [\#(natures.map { "\"\($0)\"" }.joined(separator: ", "))]}}
            """#
    }
}
