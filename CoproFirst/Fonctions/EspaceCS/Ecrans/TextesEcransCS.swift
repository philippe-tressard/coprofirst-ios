// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Les mots de l'onglet « Écrans du hall », repris du site (`OngletEcrans.svelte`, v3.117.0) :
/// la vue et les tests les lisent ici.
enum TextesEcransCS {
    static let appairer = "Appairer un écran"
    static let aideCode = """
        Sur l'écran du hall, ouvrez l'application CoproFirst : elle affiche un code de huit lettres, \
        valable dix minutes. Saisissez-le ici.
        """
    static let code = "Code affiché par l'écran"
    static let codeExemple = "BCDF-GHJK"
    static let nom = "Nom de l'écran"
    static let nomExemple = "Hall du bâtiment 2"
    static let perimetre = "Annonces affichées"
    static let aidePerimetre = """
        L'écran affiche le titre, le message et les photos des annonces de hall en cours qui \
        concernent ce périmètre, sans l'auteur ni les destinataires. Il ne peut rien modifier.
        """

    static let videTitre = "Aucun écran appairé"
    static let videMessage = "Un écran appairé fait défiler les annonces de hall dans le hall de la résidence."
    static let echu = "Échu : à appairer de nouveau"
    static let aucuneLecture = "Aucune lecture pour le moment"

    static let retirer = "Retirer"
    static let retirerTitre = "Retirer cet écran"
    static let retire = "Écran retiré"

    static func appaire(_ nom: String) -> String {
        "« \(nom) » est appairé : l'écran reçoit son accès dans quelques secondes."
    }

    static func retirerMessage(_ ecran: EcranDuHall) -> String {
        """
        « \(ecran.nom) » cessera aussitôt d'afficher les annonces. \
        Pour le remettre en service, il faudra l'appairer de nouveau.
        """
    }

    static func retirerLibelle(_ ecran: EcranDuHall) -> String { "Retirer l'écran \(ecran.nom)" }

    /// « Dernière lecture : 18 nov. 2026, 08:42 · appairé le 02/11/2026 ».
    static func lecture(_ ecran: EcranDuHall) -> String {
        let lu = ecran.vuLe.map { "Dernière lecture : \(FormatsDuSite.dateHeure($0))" } ?? aucuneLecture
        return lu + Separateur.point + "appairé le \(FormatsDuSite.dateCourte(ecran.creeLe))"
    }

    /// Le temps qu'un écran met à venir chercher son accès : il interroge toutes les 5 s
    /// (`RELECTURE_APRES_APPAIRAGE_MS` du site). La liste se relit une fois après.
    static let relectureApresAppairage: Duration = .seconds(8)
}
